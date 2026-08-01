# boter.eu

Personal site and portfolio of Riccardo Coluccini, freelance journalist covering hacking and surveillance.

Built with Jekyll, deployed by GitHub Pages from `main` — pushing to `main` publishes the site. The live domain is set by `CNAME`.

## Running it locally

Needs **Ruby < 4.0**; `.ruby-version` pins 3.2.6. (The `github-pages` gem depends on `commonmarker`, which does not support Ruby 4, so `bundle install` fails outright on a newer Ruby.)

```bash
bundle install
bundle exec jekyll serve      # http://127.0.0.1:4000
```

Editing `_config.yml` requires restarting the server; everything else rebuilds automatically.

## Adding content

**A work** (the `/works` grid) lives entirely in `_data/works.json` — name, years, description, images and links. Each work also needs a stub page in `_work/` whose permalink slug matches its JSON key; `bin/generate-work-stubs.rb` writes those. Year labels come from `start`/`end`: `current` renders `(current)`, differing years render `(2020-2026)`, and a single year renders on its own.

**A note** (the `/activity_feed/` page) is an ordinary Jekyll post — `_posts/YYYY-MM-DD-slug.md` with `layout: post` and a `title`. It also gets its own page at `/YYYY/MM/DD/slug.html`.

**An article you published elsewhere** goes in the Atom feed at `/feed.xml`, which is generated from `_data/articles.yml`:

```bash
bundle exec ruby bin/add-article.rb https://irpimedia.irpi.eu/some-article/
```

That reads the title, summary and date from the page's Open Graph tags, generates a uuid, and inserts the entry in date order. Use `--title`, `--summary`, `--date` when a publisher omits a tag, and `--dry-run` to preview. **Never edit an existing entry's `id`** — feed readers use it to tell posts apart, so changing one re-notifies every subscriber.

## Automation

| Workflow | Trigger | What it does |
|---|---|---|
| `.github/workflows/ci.yml` | pull requests, pushes to `main` | Builds the site from `Gemfile.lock` and audits it for known gem vulnerabilities |
| `.github/workflows/syndicate.yml` | a new file in `_posts/` | Cross-posts the note as a thread to Bluesky, Mastodon and Twitter/X |
| `.github/dependabot.yml` | weekly | Opens one grouped PR for gem updates and one for action updates |

GitHub Pages builds the deployed site with its own pinned gems and **ignores this repo's `Gemfile.lock`**. CI builds from the lockfile instead, so a bad dependency bump surfaces in the PR rather than after merging.

### Syndication

`bin/syndicate.rb` splits a post into a thread that fits each platform, respecting how each one counts: Bluesky counts graphemes and charges a URL its full length, while Twitter and Mastodon count any URL as 23 characters. The permalink lands on the final message.

Set only the secrets you have — a platform without credentials is skipped, not failed:

- `BLUESKY_HANDLE`, `BLUESKY_APP_PASSWORD` (an app password, never the account password)
- `MASTODON_INSTANCE`, `MASTODON_TOKEN` (scope `write:statuses`)
- `TWITTER_API_KEY`, `TWITTER_API_SECRET`, `TWITTER_ACCESS_TOKEN`, `TWITTER_ACCESS_SECRET`

`.github/syndicated.yml` records what has already been posted and is committed back by the workflow, so a re-run can never duplicate a thread. Preview anything before it goes out:

```bash
ruby bin/syndicate.rb --post _posts/2026-08-01-nota.md --dry-run --force
```

The workflow's manual trigger defaults `dry_run` to true for the same reason.

## Layout notes

- `remote_theme: jirrian/jekyll-theme-image-grid` supplies the base stylesheet and the `post` layout; everything else is overridden in `_layouts/`.
- Pages come in two colorways, keyed off the page title: `home` (blue) and `works` (white). Much of `_sass/jzhong_style.scss` is scoped to one or the other.
- Grid images are lazy-loaded, so **every image needs a matching low-res file of the same name in `assets/portfolio_images/placeholders/`**.
- Jekyll renders any Markdown file at the repo root into the site, so `README.md` and `CLAUDE.md` are listed in `exclude` in `_config.yml`. Note that setting `exclude` *replaces* Jekyll's defaults, so the defaults are repeated there by hand.
- Maintenance scripts belong in `bin/` (excluded from the build), never in `script/`, which is published as the site's JavaScript.

`CLAUDE.md` holds the deeper implementation notes and the gotchas worth knowing before changing templates.

## Known issue

`assets/portfolio_images/placeholders/screen_lighthouse_coluccini.png` is missing, so the Lighthouse Reports card shows a broken image until it scrolls into view. The other three works have their placeholder.
