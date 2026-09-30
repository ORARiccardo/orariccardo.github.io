source "https://rubygems.org"

# The site is built by .github/workflows/pages.yml from this Gemfile.lock, so the
# versions here are exactly what gets deployed. Run Jekyll with `bundle exec`:
#
#     bundle exec jekyll serve
#
gem "jekyll", "~> 4.4"

# Theme gem: supplies assets/style.css and the `post` layout (see _config.yml)
gem "jekyll-theme-image-grid"

group :jekyll_plugins do
  gem "jekyll-seo-tag", "~> 2.8"
end

# Windows and JRuby does not include zoneinfo files, so bundle the tzinfo-data gem
# and associated library.
platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo", ">= 1", "< 3"
  gem "tzinfo-data"
end

# Performance-booster for watching directories on Windows
gem "wdm", "~> 0.1.1", :platforms => [:mingw, :x64_mingw, :mswin]

gem "webrick", "~> 1.7"

# Local/CI only, not needed to build the site.
group :development do
  # Checks Gemfile.lock against the Ruby advisory database
  gem "bundler-audit", "~> 0.9"
  # Parses article pages in bin/add-article.rb and validates feed.xml in CI
  gem "nokogiri", "~> 1.18"
end
