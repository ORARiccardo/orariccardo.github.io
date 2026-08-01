# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal portfolio site of a freelance journalist (boter.eu), built with Jekyll and deployed by GitHub Pages from the default branch of `ORARiccardo/orariccardo.github.io` (see `CNAME`). Pushing to `main` is the deploy: GitHub Pages builds the site itself, with its own pinned gem set, **ignoring this repo's `Gemfile.lock`**. The CI workflow in `.github/workflows/ci.yml` builds from the lockfile on every PR, so it protects local/CI reproducibility and catches breaking dependency bumps — it does not produce the deployed site. No tests exist.

## Commands

```bash
bundle install                       # first-time setup
bundle exec jekyll serve             # local dev server at http://127.0.0.1:4000 (--livereload for auto-reload)
bundle exec jekyll build             # output to _site/
bundle exec bundler-audit check --update   # CVE check against Gemfile.lock
bundle exec ruby bin/add-article.rb <url>  # add an article to the feed (see below)
```

**Requires Ruby < 4.0**, pinned to 3.2.6 by `.ruby-version`. The `github-pages` gem pulls in `commonmarker`, which caps at Ruby < 4.0, so `bundle install` fails outright on Ruby 4.x with a version-solving error. If your shell defaults to a newer Ruby, select it explicitly (e.g. `export RBENV_VERSION=3.2.6`).

`_config.yml` is not reloaded by `serve` — restart the process after editing it.

Two config gotchas: Jekyll renders **any** Markdown file at the repo root into the published site (that is why `CLAUDE.md` is in `exclude`), and setting `exclude` **replaces** Jekyll's default exclusions rather than extending them, so the defaults are repeated there by hand — keep them when adding entries.

The gem set is pinned by the `github-pages` gem (Jekyll 3.10) so local builds match GitHub Pages. `.github/dependabot.yml` opens grouped weekly bundler PRs (on top of GitHub's repo-level security updates), and `Gemfile.lock` carries gem checksums — regenerate them with `bundle lock --add-checksums` if the section is ever lost.

## Content model

Everything on `/works` is driven by a single file: **`_data/works.json`**. The Markdown files in `_work/` and `_medium/` are near-empty stubs that exist only to make Jekyll emit a page at a permalink; all titles, years, descriptions, images, and links are read back out of `site.data.works` by the layouts.

- `_data/works.json` — keys are work slugs; each value has `name`, `year.start`/`year.end`, `description.medium`/`description.concept`, `mediums[]` (tags used for nav filtering), `preview`, `photos[]`, and `links` (`video`, `blog[]`, `demo`, `external{label: url}`).
- `_work/<slug>.md` — front matter only (`title`, `permalink: /works/<slug>`). `_layouts/work.html` derives the slug from the last path segment of `page.permalink` and looks the entry up in `site.data.works`, so **the permalink's last segment must exactly match the JSON key**.
- `_medium/<medium>.md` — front matter with a `medium:` key. `_layouts/works.html` renders the grid filtered to works whose `mediums[]` contains `page.medium`; `_includes/header.html` iterates `site.medium` to build the nav.
- `bin/generate-work-stubs.rb` regenerates those stubs from `works.json` (`bundle exec ruby bin/generate-work-stubs.rb [output_root]`; it replaced `_data/post_mdfile_generator.py`, which needed PyYAML). The `_work/` stubs come out byte-identical to what is committed, but `_medium/` is hand-curated — display titles, work-page permalinks, and one different filename — so re-running it clobbers that. Pass an `output_root` to write elsewhere and diff. Manual tool only; never a build step.

### works.json is parsed as YAML, not JSON

`articles-lighthouse-reports` carries `"end": current` — a bare word that is invalid JSON. Jekyll loads `.json` data files through its YAML parser, where this is simply the string `"current"`. Don't "fix" it to valid JSON without checking the rendered year still reads correctly. Any Python tooling over this file needs a YAML parser, not `json`.

### Year labels

`_includes/work-year.html` renders every year label, from `year.start`/`year.end`: `end == "current"` prints `(current)`, an unequal start and end prints `(start-end)`, and otherwise just `(end)`. Both `works.html` and `work.html` use it, so a card and its detail page can't drift apart. Jekyll's include tag rejects bracket lookups in parameters, hence the `assign work_year = ...` immediately before each call.

The include must keep emitting `class="year"`: `script/sort.js` orders the grid by that text, comparing it as a string. Descending string order happens to give the intended newest-first result for the current labels (`(current)` > `(2020-2026)` > `(2018-2025)` > `(2016-2022)`) — a label that doesn't start with its most significant year would break that.

### Medium and work permalinks collide

The committed `_medium/*.md` files point their permalinks at a work page (e.g. `_medium/articles-irpi.md` → `/works/articles-irpi-media`), the same permalink as `_work/articles-irpi-media.md`. One output silently overwrites the other with no build warning — the work detail page wins, so nav "medium" links land on the work page rather than a filtered grid. That is harmless while there is exactly one work per medium; if a medium gains a second work, give the medium pages their own permalinks (`/works/<medium>`, as the generator script produces) or the filtered grid stays unreachable.

## Layouts and theming

`remote_theme: jirrian/jekyll-theme-image-grid` supplies `assets/style.css` and the `post` layout; everything else is overridden locally. `_layouts/default.html` (and its near-duplicate `posts.html`, which exists only to give the activity feed the "home" colorway) branch on `page.title` to set a body class of `home` (blue) vs `works` (white) — this "colorway" is passed into `_includes/header.html`, and much of `_sass/jzhong_style.scss` is scoped under `.home` / `.works`. Adding a page means deciding which colorway it gets.

Styling entry point is `assets/jzhong_style.scss` (empty front matter triggers Sass compilation), which imports `_sass/jzhong_style.scss` and the vendored `_sass/rfs.scss` (from the npm `rfs` package — `package-lock.json` exists only to pin it; there is no npm build step). Bootstrap 5 beta and Bootstrap Icons load from CDNs in `_includes/bootstrap-style.html` / `head.html`.

## Front-end scripts

`script/*.js` are plain DOMContentLoaded scripts included ad hoc by the layout that needs them (no bundler). Two coupling points worth knowing:

- Images/videos are lazy-loaded: markup points `src` at a low-res file in `assets/portfolio_images/placeholders/` (or `portfolio_videos/placeholders/`, a `.png` poster) and the real file in `data-src`; `lazyloading.js` swaps them via IntersectionObserver. **Every asset needs a matching placeholder of the same filename**, or the grid renders blank until scroll.
- `sort.js` re-orders the works grid client-side by the text inside `.year`, and `clickableCards.js` makes each `.card` click through to its `.main-link`. `works.html` must keep emitting `.col-`, `.year`, and `.main-link` for both to work.
- `displayLogo.js` / `navHover.js` drive the anime.js title and nav animations and assume `.ml11 .letters` and `.ml12` exist in the header; `navHover.js` runs unconditionally and throws if `.ml12` is absent.

## Blog and feeds

`_posts/` uses the theme's `post` layout, surfaced by `activity_feed.markdown` (`/activity_feed/`) and `_layouts/activity.html`. The layout is chrome only — it renders `{{ content }}`, and the page owns the post loop.

`feed.xml` is an Atom feed of **externally published articles**, unrelated to `_posts`. It is a Liquid template over `_data/articles.yml`, sorted by `published` descending, with the feed-level `<updated>` taken from the newest entry (not `site.time`, so unrelated rebuilds don't churn the feed).

Add an article with `bundle exec ruby bin/add-article.rb <url>`, which reads `og:title` / `og:description` / `article:published_time` from the page, generates a uuid, and appends a sorted entry; `--title`, `--summary`, `--date` override anything the publisher omits, and `--dry-run` prints without writing. **Never change or regenerate an existing entry's `id`** — feed readers dedupe on it, and every subscriber would see the article again as new.

Dates are RFC 3339 strings in UTC; bare `YYYY-MM-DD` input is stored as noon UTC, matching the pre-existing entries.

`bin/` is excluded from the built site. Maintenance scripts must not go in `script/`, which is published and served as the site's JavaScript.

## Syndication

Pushing a new `_posts/*.md` to `main` triggers `.github/workflows/syndicate.yml`, which cross-posts it as a thread to Bluesky, Mastodon and Twitter/X via `bin/syndicate.rb` (stdlib only — no bundle in CI).

- The chunker strips Markdown to plain text, then splits on paragraph → sentence → word boundaries, appends ` n/m` counters, and puts the permalink on the final message. Limits differ per platform and so does *counting*: Bluesky counts graphemes and charges the full length of a URL, while Twitter and Mastodon count any URL as 23 characters — so the same post can be 4 messages on Bluesky and 3 on Mastodon.
- **`.github/syndicated.yml` is the duplicate guard.** A post recorded there is never sent again, and the workflow commits the file back after posting. Removing an entry re-posts it; `--force` bypasses the file locally.
- A platform whose secrets are missing is skipped rather than failing the run, so this works with one account or three.
- Preview before anything goes out: `ruby bin/syndicate.rb --post _posts/<file>.md --dry-run --force`, or run the workflow manually (`workflow_dispatch` defaults `dry_run` to true).
