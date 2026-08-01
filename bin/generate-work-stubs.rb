#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerate the _work/ and _medium/ stub pages from _data/works.json.
#
#   bundle exec ruby bin/generate-work-stubs.rb [output_root]
#
# works.json is read as YAML, not JSON: it contains bare words such as
# `"end": current` which Jekyll accepts (it reads .json data files through its
# YAML parser) but a JSON parser rejects.
#
# Careful - this is a manual tool, never a build step. The _work/ stubs
# regenerate byte-identically, but the committed _medium/*.md files are heavily
# hand-curated: display titles ("Irpimedia", not "articles irpi"), permalinks
# pointing at a work page instead of /works/<medium>, and in one case a
# different filename. Re-running this overwrites all of that. Pass an
# output_root to write the stubs somewhere harmless and diff them first.

require "fileutils"
require "yaml"

root = ARGV[0] || File.expand_path("..", __dir__)
works = YAML.safe_load(File.read(File.expand_path("../_data/works.json", __dir__)))

work_dir = File.join(root, "_work")
medium_dir = File.join(root, "_medium")
FileUtils.mkdir_p([work_dir, medium_dir])

mediums = []
works.each do |slug, work|
  File.write(File.join(work_dir, "#{slug}.md"),
             "---\ntitle: #{work['name']}\npermalink: /works/#{slug}\n---")
  mediums |= work["mediums"]
end

mediums.each do |medium|
  File.write(File.join(medium_dir, "#{medium}.md"),
             "---\ntitle: #{medium.tr('-', ' ')}\nmedium: #{medium}\npermalink: /works/#{medium}\n---")
end

puts "wrote #{works.size} work stubs and #{mediums.size} medium stubs under #{root}"
