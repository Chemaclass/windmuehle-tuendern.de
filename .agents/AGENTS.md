# Windmühle Tündern - Project Instructions

## For AI agents (Claude, Codex, ChatGPT, ...)

This file is the single source of truth for agent instructions. Root `AGENTS.md` and `CLAUDE.md` are symlinks to `.agents/AGENTS.md`; `.claude/agents` and `.claude/skills` symlink into `.agents/`. Edit files under `.agents/`, never the symlinks.

`content/` and `data/` also carry a scoped `AGENTS.md` (+ `CLAUDE.md`), symlinked from `.agents/nested/`, that Codex merges when working in that subtree. Zola ignores them via `ignored_content` in `config.toml`. `templates/` deliberately has none: Zola parses every file there as a Tera template.

Detailed task playbooks live in `.agents/skills/<name>/SKILL.md`. Claude auto-runs them as skills; other agents (Codex, ...) read the matching SKILL.md before the task and follow its body — skip the YAML frontmatter, which is Claude-only trigger metadata. The body is plain, tool-neutral procedure.

- `new-post` — write a trilingual (DE/EN/ES) blog post: voice, image layout, thumbnails
- `new-tour` — add / update / cancel a Führungen slot or event in `data/fuehrungen.toml`
- `i18n-sync` — audit DE/EN/ES translation parity
- `build-check` — run `zola build` and report

Helper scripts (any agent can run these directly):

- `./scripts/setup.sh` — install the pinned Zola + Python deps. Run this FIRST in a fresh sandbox (e.g. Codex) so `zola build` and the validators work; skip if `zola build` already runs.
- `./start-local.sh` — serve at http://127.0.0.1:1111
- `./scripts/new-post.sh` / `./scripts/make-thumb.sh` — scaffold a post / optimize an image + thumbnail
- `./scripts/new-tour.sh` — append a public/private tour slot (events are manual, see new-tour playbook)
- `./scripts/validate-fuehrungen.py` — validate tour data (needs Python 3.11+)
- `./scripts/check-links.py` — resolve every link and image in `public/` (run after `zola build`)

Verify any change before committing: `./scripts/validate-fuehrungen.py`, `./scripts/check-i18n.py`, then `zola build` and `./scripts/check-links.py` — the same gates CI runs on the pull request and before every deploy. `zola build` alone stays green on dead links and missing images, so never skip the last one after touching templates, image paths or filenames.

Claude-only extras: subagent role docs in `.agents/agents/*.md` (blog-post-creator, i18n-checker, seo-auditor).

## Tech Stack

- **SSG**: [Zola](https://www.getzola.org/). Build `zola build`, serve `zola serve`.
- **Templates**: Tera (`.html` files in `templates/`)
- **Styles**: Sass (`sass/main.scss`), compiled by Zola
- **Hosting**: static GitHub Pages, CNAME `windmuehle-tuendern.de`
- **Local preview**: `./start-local.sh` (wraps `zola serve`, default `http://127.0.0.1:1111`)

## Trilingual Architecture

The site supports three languages: **German (de, default)**, **English (en)**, **Spanish (es)**.

Every content or translation change **must** cover all 3 languages.

### Where translations live

| Location | DE | EN | ES |
|---|---|---|---|
| config.toml keys | `[translations]` | `[languages.en.translations]` | `[languages.es.translations]` |
| Nav items | `[extra.nav.de]` | `[extra.nav.en]` | `[extra.nav.es]` |
| Content pages | `content/` | `content/en/` | `content/es/` |
| Templates | `{% if lang == "de" %}` / `{% elif lang == "en" %}` / `{% else %}` blocks |

### Translation rules

- Never leave a language behind. If one language is updated, all three must match.
- Preserve HTML tags, markdown formatting, and structure identically across languages.
- Dates and proper nouns must stay consistent ("Tündern" is never translated).
- When unsure about a translation, flag it for human review.

## Blog Posts

- Live in `content/aktuelles/` (de), `content/en/aktuelles/` (en), `content/es/aktuelles/` (es)
- Filename `YYYY-MM-DD-slug.md`. Zola derives `page.date` from it, so no `date` field in frontmatter. One slug per post: recurring events carry the year (`pfingstmontag-2027`).
- Frontmatter: `title`, `description`, `template = "blog-post.html"`, `[extra] image`
- Images in `static/imgs/`, referenced absolute (`/imgs/...`). Galleries use `<div class="post-images">`.
- Optimize post images to 1200px / 80% JPEG; thumbnails to 600px / 70% into `static/imgs/thumbs/<basename>.jpg`. Every `[extra] image` needs a matching thumbnail.
- Full writing guide (voice, image layout, trilingual workflow): `.agents/skills/new-post/SKILL.md` (Claude: the `new-post` skill).
- Hard rules: cover DE+EN+ES (leave `<!-- TODO: translate -->` if you cannot). No em/en dashes in prose. Plain, warm, German-native voice, first-person plural (`wir`).

## Führungen (guided tours) data

- Source of truth: `data/fuehrungen.toml`. One `[[slots]]` table per tour. No DB yet.
- Schema (validated by `scripts/validate-fuehrungen.py`):
  - `date` ISO `YYYY-MM-DD`, Europe/Berlin
  - `time` `HH:MM` 24h
  - `duration_min` integer, defaults to 60
  - `kind` `"public"`, `"private"` or `"event"` (non-tour events such as a concert)
  - `status` `"free"`, `"booked"` or `"cancelled"`; private slots cannot be `"free"`
  - `guide` optional string, first name(s) of the tour guide
  - event slots (`kind = "event"`) also use: `title` (required), `location` (optional venue when it is not the mill), `free_entry` (optional bool, `true` shows an "Eintritt frei" badge)
- Private slots render opaque. Never include family names or other identifiers in the data file.
- Phone numbers on the contact card are base64-encoded server-side, revealed on click. When changing one, update `data-display`, `data-tel`, `data-wa` in `templates/fuehrungen.html` via Tera's `base64_encode` filter.
- JSON-LD `Event` schema emits for upcoming public tours and events (non-cancelled).
- After editing, run `scripts/validate-fuehrungen.py`. Run `zola build` before committing.

## Conventions

- Conventional commits (no AI/Claude mentions)
- `zola build` must pass before committing
- Keep translation keys in `config.toml` in the same order across all 3 language sections
