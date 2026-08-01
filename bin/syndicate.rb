#!/usr/bin/env ruby
# frozen_string_literal: true

# Cross-post an activity-feed entry (_posts/*.md) to Bluesky, Mastodon and
# Twitter/X, splitting it into a thread that fits each platform's limit.
#
#   bin/syndicate.rb --post _posts/2026-08-01-nota.md --dry-run
#   bin/syndicate.rb --post _posts/2026-08-01-nota.md
#   bin/syndicate.rb --since <git-sha>            # every post added since that commit
#
# Credentials come from the environment; a platform whose credentials are
# missing is skipped, not failed:
#
#   BLUESKY_HANDLE, BLUESKY_APP_PASSWORD          (app password, never the account password)
#   MASTODON_INSTANCE, MASTODON_TOKEN             (instance host, e.g. mastodon.social)
#   TWITTER_API_KEY, TWITTER_API_SECRET, TWITTER_ACCESS_TOKEN, TWITTER_ACCESS_SECRET
#
# Posts already recorded in .github/syndicated.yml are never sent again, so
# re-running a workflow cannot duplicate a thread.
#
# Stdlib only, deliberately: this runs in CI without a bundle install.

require "base64"
require "digest"
require "json"
require "net/http"
require "openssl"
require "optparse"
require "securerandom"
require "time"
require "uri"
require "yaml"

ROOT = File.expand_path("..", __dir__)
STATE_FILE = File.join(ROOT, ".github", "syndicated.yml")
SITE_URL = "https://boter.eu"

# Post length limits. Bluesky counts graphemes; Twitter and Mastodon count any
# URL as a fixed 23 characters however long it is.
LIMITS = { bluesky: 300, mastodon: 500, twitter: 280 }.freeze
URL_COST = { bluesky: nil, mastodon: 23, twitter: 23 }.freeze
URL_PATTERN = %r{https?://[^\s<>"')\]]+}

# Room for the " 12/34" thread counter appended to every chunk of a thread.
COUNTER_RESERVE = 6

module Text
  module_function

  # Markdown is written for the web page; social posts want plain text.
  def plain(markdown)
    text = markdown.dup
    text.gsub!(/^!\[[^\]]*\]\([^)]*\)\s*$/, "")        # images
    text.gsub!(/\[([^\]]+)\]\(([^)]+)\)/) { "#{Regexp.last_match(1)} (#{Regexp.last_match(2)})" }
    text.gsub!(/^\s{0,3}#{'#'}{1,6}\s*/, "")           # headings
    text.gsub!(/^\s{0,3}>\s?/, "")                     # blockquotes
    text.gsub!(/^\s*[-*+]\s+/, "• ")                   # list bullets
    text.gsub!(/\*\*([^*]+)\*\*/, '\1')
    text.gsub!(/(?<!\*)\*([^*]+)\*(?!\*)/, '\1')
    text.gsub!(/`([^`]+)`/, '\1')
    text.gsub!(/\n{3,}/, "\n\n")
    text.strip
  end

  # What the platform thinks the text is worth, not what String#length says.
  def cost(text, platform)
    counted = if (url_cost = URL_COST[platform])
                text.gsub(URL_PATTERN) { "x" * url_cost }
              else
                text
              end
    counted.grapheme_clusters.size
  end

  # Greedy fill on paragraph -> sentence -> word boundaries, so a thread breaks
  # where a reader would break it.
  def chunks(text, platform, limit)
    pieces = []
    text.split(/\n{2,}/).each do |paragraph|
      if cost(paragraph, platform) <= limit
        pieces << paragraph
      else
        paragraph.split(/(?<=[.!?…])\s+/).each do |sentence|
          if cost(sentence, platform) <= limit
            pieces << sentence
          else
            pieces.concat(split_words(sentence, platform, limit))
          end
        end
      end
    end

    pack(pieces, platform, limit)
  end

  def split_words(sentence, platform, limit)
    out = []
    current = +""
    sentence.split(/\s+/).each do |word|
      word = hard_split(word, platform, limit, out) if cost(word, platform) > limit
      candidate = current.empty? ? word : "#{current} #{word}"
      if cost(candidate, platform) <= limit
        current = candidate
      else
        out << current unless current.empty?
        current = word
      end
    end
    out << current unless current.empty?
    out
  end

  # A single token longer than the whole limit (a very long URL) has to be cut.
  def hard_split(word, platform, limit, out)
    clusters = word.grapheme_clusters
    while cost(clusters.join, platform) > limit
      out << clusters.shift(limit).join
    end
    clusters.join
  end

  def pack(pieces, platform, limit)
    chunks = []
    current = +""
    pieces.each do |piece|
      candidate = current.empty? ? piece : "#{current}\n\n#{piece}"
      if cost(candidate, platform) <= limit
        current = candidate
      else
        chunks << current unless current.empty?
        current = piece
      end
    end
    chunks << current unless current.empty?
    chunks
  end
end

# Turns one post into the exact list of messages a platform will receive.
# (Not "Thread" - that name is taken by Ruby itself.)
class PostThread
  def initialize(title:, body:, url:)
    @title = title
    @body = body
    @url = url
  end

  def for(platform)
    limit = LIMITS.fetch(platform)
    text = [@title, @body].reject { |part| part.to_s.strip.empty? }.join("\n\n")

    single = [@title, @body, @url].reject { |p| p.to_s.strip.empty? }.join("\n\n")
    return [single] if Text.cost(single, platform) <= limit

    chunks = Text.chunks(text, platform, limit - COUNTER_RESERVE)
    chunks = append_link(chunks, platform, limit - COUNTER_RESERVE)
    number(chunks, platform)
  end

  private

  # The permalink belongs at the end of the thread; it gets its own message
  # only when it cannot fit on the last one.
  def append_link(chunks, platform, limit)
    with_link = "#{chunks.last}\n\n#{@url}"
    if Text.cost(with_link, platform) <= limit
      chunks[0..-2] + [with_link]
    else
      chunks + [@url]
    end
  end

  def number(chunks, platform)
    return chunks if chunks.size < 2

    total = chunks.size
    chunks.each_with_index.map do |chunk, i|
      numbered = "#{chunk} #{i + 1}/#{total}"
      # Should never trip, since COUNTER_RESERVE was held back above.
      raise "chunk #{i + 1} overruns the #{platform} limit" if Text.cost(numbered, platform) > LIMITS.fetch(platform)

      numbered
    end
  end
end

module HTTP
  module_function

  def request(method, url, headers: {}, body: nil, form: nil)
    uri = URI.parse(url)
    klass = method == :post ? Net::HTTP::Post : Net::HTTP::Get
    request = klass.new(uri)
    headers.each { |k, v| request[k] = v }
    if form
      request.set_form_data(form)
    elsif body
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body)
    end

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
    unless response.is_a?(Net::HTTPSuccess)
      raise "#{method.to_s.upcase} #{url} -> #{response.code} #{response.body.to_s[0, 400]}"
    end

    response.body.to_s.empty? ? {} : JSON.parse(response.body)
  end
end

class Bluesky
  NAME = :bluesky

  def self.from_env
    handle = ENV["BLUESKY_HANDLE"]
    password = ENV["BLUESKY_APP_PASSWORD"]
    return nil if handle.to_s.empty? || password.to_s.empty?

    new(handle, password, ENV["BLUESKY_PDS"] || "https://bsky.social")
  end

  def initialize(handle, password, pds)
    @handle = handle
    @password = password
    @pds = pds
  end

  def post_thread(chunks)
    session = HTTP.request(:post, "#{@pds}/xrpc/com.atproto.server.createSession",
                           body: { identifier: @handle, password: @password })
    auth = { "Authorization" => "Bearer #{session['accessJwt']}" }

    root = nil
    parent = nil
    chunks.map do |chunk|
      record = {
        "$type" => "app.bsky.feed.post",
        text: chunk,
        createdAt: Time.now.utc.iso8601(3),
        langs: ["it"],
        facets: link_facets(chunk),
      }
      record[:reply] = { root: root, parent: parent } if root

      result = HTTP.request(:post, "#{@pds}/xrpc/com.atproto.repo.createRecord", headers: auth,
                                                                                body: { repo: session["did"],
                                                                                        collection: "app.bsky.feed.post",
                                                                                        record: record })
      ref = { uri: result["uri"], cid: result["cid"] }
      root ||= ref
      parent = ref
      result["uri"]
    end.last
  end

  private

  # Without facets a URL is inert text, so links have to be marked up by byte
  # offset into the UTF-8 encoding of the message.
  def link_facets(text)
    bytes = text.dup.force_encoding(Encoding::BINARY)
    text.enum_for(:scan, URL_PATTERN).map do
      match = Regexp.last_match[0]
      start = bytes.index(match.dup.force_encoding(Encoding::BINARY))
      {
        index: { byteStart: start, byteEnd: start + match.bytesize },
        features: [{ "$type" => "app.bsky.richtext.facet#link", uri: match }],
      }
    end
  end
end

class Mastodon
  NAME = :mastodon

  def self.from_env
    instance = ENV["MASTODON_INSTANCE"]
    token = ENV["MASTODON_TOKEN"]
    return nil if instance.to_s.empty? || token.to_s.empty?

    new(instance.sub(%r{\Ahttps?://}, "").chomp("/"), token)
  end

  def initialize(instance, token)
    @instance = instance
    @token = token
  end

  def post_thread(chunks)
    reply_to = nil
    last_url = nil
    chunks.each_with_index do |chunk, i|
      body = { status: chunk, visibility: "public", language: "it" }
      body[:in_reply_to_id] = reply_to if reply_to

      status = HTTP.request(:post, "https://#{@instance}/api/v1/statuses",
                            headers: {
                              "Authorization" => "Bearer #{@token}",
                              # Makes a retried request a no-op instead of a duplicate toot
                              "Idempotency-Key" => "#{idempotency_key(chunks)}-#{i}",
                            },
                            body: body)
      reply_to = status["id"]
      last_url = status["url"]
    end
    last_url
  end

  private

  def idempotency_key(chunks)
    Digest::SHA256.hexdigest(chunks.join("\n"))[0, 16]
  end
end

class Twitter
  NAME = :twitter
  ENDPOINT = "https://api.twitter.com/2/tweets"

  def self.from_env
    keys = %w[TWITTER_API_KEY TWITTER_API_SECRET TWITTER_ACCESS_TOKEN TWITTER_ACCESS_SECRET].map { |k| ENV[k] }
    return nil if keys.any? { |k| k.to_s.empty? }

    new(*keys)
  end

  def initialize(api_key, api_secret, access_token, access_secret)
    @api_key = api_key
    @api_secret = api_secret
    @access_token = access_token
    @access_secret = access_secret
  end

  def post_thread(chunks)
    reply_to = nil
    chunks.each do |chunk|
      body = { text: chunk }
      body[:reply] = { in_reply_to_tweet_id: reply_to } if reply_to

      result = HTTP.request(:post, ENDPOINT, headers: { "Authorization" => authorization(ENDPOINT) }, body: body)
      reply_to = result.dig("data", "id")
    end
    reply_to && "https://twitter.com/i/status/#{reply_to}"
  end

  private

  # OAuth 1.0a user context. A JSON body is not part of the signature base.
  def authorization(url)
    params = {
      "oauth_consumer_key" => @api_key,
      "oauth_nonce" => SecureRandom.hex(16),
      "oauth_signature_method" => "HMAC-SHA1",
      "oauth_timestamp" => Time.now.to_i.to_s,
      "oauth_token" => @access_token,
      "oauth_version" => "1.0",
    }

    base = ["POST", escape(url), escape(params.sort.map { |k, v| "#{escape(k)}=#{escape(v)}" }.join("&"))].join("&")
    key = "#{escape(@api_secret)}&#{escape(@access_secret)}"
    params["oauth_signature"] = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA1", key, base))

    "OAuth " + params.sort.map { |k, v| "#{escape(k)}=\"#{escape(v)}\"" }.join(", ")
  end

  def escape(value)
    URI.encode_www_form_component(value.to_s).gsub("+", "%20").gsub("%7E", "~")
  end
end

module Posts
  module_function

  def parse(path)
    raw = File.read(File.join(ROOT, path))
    match = raw.match(/\A---\s*\n(.*?\n)---\s*\n(.*)\z/m)
    raise "#{path} has no front matter" unless match

    front = YAML.safe_load(match[1], permitted_classes: [Date, Time]) || {}
    { title: front["title"].to_s, body: Text.plain(match[2]), url: url_for(path) }
  end

  # Jekyll's default permalink for a post: /YYYY/MM/DD/slug.html
  def url_for(path)
    captures = File.basename(path, ".md").match(/\A(\d{4})-(\d{2})-(\d{2})-(.+)\z/)&.captures
    raise "#{path} is not named YYYY-MM-DD-slug.md" if captures.nil?

    year, month, day, slug = captures
    "#{SITE_URL}/#{year}/#{month}/#{day}/#{slug}.html"
  end

  def added_since(sha)
    diff = `git -C #{ROOT} diff --name-status #{sha} HEAD -- _posts/`
    raise "could not diff against #{sha}" unless $?.success?

    diff.lines.filter_map do |line|
      status, path = line.split("\t", 2)
      path&.strip if status.start_with?("A")
    end
  end
end

module State
  module_function

  def load
    return {} unless File.exist?(STATE_FILE)

    YAML.safe_load(File.read(STATE_FILE)) || {}
  end

  def record(state, path, results)
    state[path] = (state[path] || {}).merge(results)
    header = <<~TEXT
      # Posts already syndicated, written by .github/workflows/syndicate.yml.
      # Delete an entry only if you genuinely want it posted to that platform again.
    TEXT
    File.write(STATE_FILE, header + state.to_yaml(line_width: -1))
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "usage: bin/syndicate.rb [--post PATH | --since SHA] [--dry-run] [--force]"
  opts.on("--post PATH", "a single post to syndicate")
  opts.on("--since SHA", "syndicate every post added between SHA and HEAD")
  opts.on("-n", "--dry-run", "print the thread instead of posting it")
  opts.on("--force", "ignore .github/syndicated.yml")
end.parse!(into: options)

# OptionParser keys "--dry-run" as :"dry-run"
dry_run = options[:"dry-run"] ? true : false
force = options[:force] ? true : false

paths =
  if options[:post]
    [options[:post].sub(%r{\A\./}, "")]
  elsif options[:since]
    Posts.added_since(options[:since])
  else
    abort "nothing to do: pass --post or --since"
  end

if paths.empty?
  puts "no new posts"
  exit 0
end

platforms = [Bluesky, Mastodon, Twitter].filter_map(&:from_env)
if platforms.empty? && !dry_run
  puts "no credentials configured for any platform - nothing to do"
  exit 0
end

state = State.load
targets = dry_run && platforms.empty? ? LIMITS.keys : platforms.map { |p| p.class::NAME }

paths.each do |path|
  post = Posts.parse(path)
  thread = PostThread.new(**post)
  puts "\n#{path} -> #{post[:url]}"

  results = {}
  targets.each do |name|
    if !force && state.dig(path, name.to_s)
      puts "  #{name}: already syndicated (#{state[path][name.to_s]})"
      next
    end

    chunks = thread.for(name)
    if dry_run
      puts "  #{name}: #{chunks.size} message(s), limit #{LIMITS[name]}"
      chunks.each_with_index { |c, i| puts "    [#{i + 1}] (#{Text.cost(c, name)}) #{c.gsub("\n", "\n        ")}" }
      next
    end

    client = platforms.find { |p| p.class::NAME == name }
    next unless client

    begin
      results[name.to_s] = client.post_thread(chunks) || true
      puts "  #{name}: posted #{chunks.size} message(s) -> #{results[name.to_s]}"
    rescue StandardError => e
      warn "  #{name}: FAILED - #{e.message}"
      results[name.to_s] = nil
    end
  end

  successful = results.reject { |_, v| v.nil? }
  State.record(state, path, successful) unless dry_run || successful.empty?
  exit 1 if results.value?(nil)
end
