#!/usr/bin/env ruby
# frozen_string_literal: true

# Add an externally published article to _data/articles.yml, which feed.xml is
# rendered from. Title, summary and date are read from the article's Open Graph
# / schema.org metadata; pass overrides when a publisher omits them.
#
#   bundle exec ruby bin/add-article.rb https://irpimedia.irpi.eu/some-article/
#   bundle exec ruby bin/add-article.rb <url> --title "..." --summary "..." --date 2026-08-01
#
# This script is excluded from the built site (see "exclude" in _config.yml).

require "nokogiri"
require "open-uri"
require "optparse"
require "securerandom"
require "time"
require "yaml"

DATA_FILE = File.expand_path("../_data/articles.yml", __dir__)
USER_AGENT = "boter.eu add-article (+https://boter.eu)"

options = {}
parser = OptionParser.new do |opts|
  opts.banner = "usage: bundle exec ruby bin/add-article.rb <url> [options]"
  opts.on("--title TITLE", "override the article title")
  opts.on("--summary SUMMARY", "override the article summary")
  opts.on("--date DATE", "override the publication date (YYYY-MM-DD or RFC 3339)")
  opts.on("-n", "--dry-run", "print the entry without writing it")
end
parser.parse!(into: options)

url = ARGV.shift
abort parser.banner if url.nil? || url.empty?

raw = File.read(DATA_FILE)
header = raw[/\A(?:#.*\n)*/].to_s
entries = YAML.safe_load(raw) || []

if entries.any? { |e| e["link"] == url }
  puts "already in #{File.basename(DATA_FILE)}: #{url}"
  exit 0
end

def meta(doc, *selectors)
  selectors.each do |selector|
    node = doc.at(selector)
    value = node && (node["content"] || node.text)
    return value.strip unless value.nil? || value.strip.empty?
  end
  nil
end

# Publishers write dates in local time; the feed is UTC. Bare YYYY-MM-DD dates
# get noon UTC, matching how the hand-written entries were dated.
def to_rfc3339(value)
  return Time.parse("#{value}T12:00:00Z").utc.strftime("%Y-%m-%dT%H:%M:%SZ") if value =~ /\A\d{4}-\d{2}-\d{2}\z/

  Time.parse(value).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
end

document =
  begin
    Nokogiri::HTML(URI.parse(url).open("User-Agent" => USER_AGENT, redirect: true, &:read))
  rescue StandardError => e
    abort "could not fetch #{url}: #{e.message}"
  end

title = options[:title] ||
        meta(document, 'meta[property="og:title"]', 'meta[name="twitter:title"]', "title")
summary = options[:summary] ||
          meta(document, 'meta[property="og:description"]', 'meta[name="description"]')
published = options[:date] ||
            meta(document, 'meta[property="article:published_time"]', "time[datetime]")

missing = { "title" => title, "summary" => summary, "date" => published }.select { |_, v| v.nil? }.keys
abort "could not read #{missing.join(', ')} from the page - pass #{missing.map { |m| "--#{m}" }.join(' ')}" if missing.any?

published = begin
  to_rfc3339(published)
rescue StandardError => e
  abort "could not parse the publication date #{published.inspect}: #{e.message}"
end

entry = {
  "title"     => title,
  "link"      => url,
  "id"        => "urn:uuid:#{SecureRandom.uuid}",
  "published" => published,
  "updated"   => published,
  "summary"   => summary,
}

puts entry.to_yaml(line_width: -1)

if options[:"dry-run"]
  puts "(dry run - nothing written)"
  exit 0
end

entries << entry
entries.sort_by! { |e| e["published"] }.reverse!
File.write(DATA_FILE, header + entries.to_yaml(line_width: -1))
puts "added to #{File.basename(DATA_FILE)} (#{entries.size} entries) - rebuild to regenerate feed.xml"
