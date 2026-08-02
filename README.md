# Windmuehle Tuendern Website

Static website for the Förderverein Windmühle Tündern e.V., the association restoring the historic windmill in Tündern.

## Updating without coding

Not a developer? See **[HOWTO.md](./HOWTO.md)**. You describe the change in plain
English to an AI assistant (OpenAI Codex in the ChatGPT desktop app, or Claude
Code); it edits the files and opens a pull request for you to approve.

## Quick Start

Prerequisite: install [Zola](https://www.getzola.org/).

```bash
zola build
./start-local.sh
```

The local preview normally runs at `http://127.0.0.1:1111`. If the port is busy, pass another one through to Zola:

```bash
./start-local.sh --port 1112
```

## Project Shape

| Area | Path |
|---|---|
| Content, German default | `content/` |
| Content, English | `content/en/` |
| Content, Spanish | `content/es/` |
| Templates | `templates/` |
| Styles | `sass/main.scss` |
| Static images | `static/imgs/` |
| Guided tours data | `data/fuehrungen.toml` |
| Utility scripts | `scripts/` |

The site is trilingual: German (`/`), English (`/en/`) and Spanish (`/es/`). Every content or translation change must be made in all three languages.

## Common Workflows

### Build and Preview

```bash
zola build
./scripts/check-links.py
./start-local.sh
```

Run both before committing. `zola build` checks templates and frontmatter; it
resolves no link and no image path, so a green build says nothing about them.

### Create an Aktuelles Post

Posts live in:

- `content/aktuelles/`
- `content/en/aktuelles/`
- `content/es/aktuelles/`

Use the helper when starting from images or boilerplate:

```bash
./scripts/new-post.sh <slug> -s "Kurze Beschreibung."
```

Useful options:

| Option | Meaning |
|---|---|
| `-d, --dir <path>` | Source image directory, defaults to `local/imgs/` |
| `-t, --title <text>` | Post title |
| `-s, --summary <text>` | Frontmatter description |
| `-D, --date <YYYY-MM-DD>` | Post date, defaults to today |

Post filenames must be `YYYY-MM-DD-<slug>.md`. Zola derives `page.date` from the filename, so do not add a `date` field to frontmatter.

After scaffolding:

1. Write the German post first.
2. Mirror the same structure in English and Spanish.
3. Group gallery images with `<div class="post-images">`.
4. Keep `[extra] image` set to an existing image in `static/imgs/`.
5. Ensure `static/imgs/thumbs/<image>.jpg` exists for the selected hero image.
6. Run `zola build`, then `./scripts/check-links.py`.

To swap a post hero image and regenerate thumbnails:

```bash
./scripts/make-thumb.sh static/imgs/<image>.jpg
```

See `content/aktuelles/2026-04-17-einweihung-der-windmuehle.md` for a structured example.

### Edit Guided Tours

Tours are stored in `data/fuehrungen.toml`. Add one `[[slots]]` table per tour:

```toml
[[slots]]
date = "2026-06-14"
time = "14:00"
kind = "public"
status = "free"
guide = "Dirk"
```

Fields:

| Field | Required | Notes |
|---|---|---|
| `date` | yes | `YYYY-MM-DD`, Europe/Berlin |
| `time` | yes | 24-hour `HH:MM` |
| `duration_min` | no | integer, defaults to `60` |
| `kind` | yes | `"public"`, `"private"` or `"event"` (non-tour, e.g. a concert) |
| `status` | yes | `"free"`, `"booked"` or `"cancelled"` |
| `guide` | no | first names only (tours) |

Private slots cannot be `"free"` and must not include family names, group names or other identifiers. They are rendered anonymously on the site.

Event slots (`kind = "event"`) use `title` (required) plus optional `location` (venue when it is not the mill) and `free_entry` (bool). Add them by editing this file directly; `new-tour.sh` handles tours only.

After editing:

```bash
./scripts/validate-fuehrungen.py
zola build
```

## Scripts

| Script | Purpose |
|---|---|
| `scripts/setup.sh` | Install the pinned Zola + Python deps (fresh machine, or Codex/CI sandbox) |
| `scripts/new-post.sh` | Scaffold trilingual Aktuelles posts, optimize images and create thumbnails |
| `scripts/make-thumb.sh` | Change a post hero image and regenerate its thumbnail |
| `scripts/optimize-imgs.sh` | Optimize source images |
| `scripts/new-tour.sh` | Append a guided tour slot |
| `scripts/validate-fuehrungen.py` | Validate `data/fuehrungen.toml` |
| `scripts/check-i18n.py` | Check translation parity |
| `scripts/check-links.py` | Resolve every link and image in `public/` (run after `zola build`) |
| `scripts/mark-for-translation.sh` | Mark Markdown files in a directory for translation |

## Testing

Script tests use bashunit:

```bash
./scripts/lib/bashunit scripts/tests
```

Add or update tests when changing script behavior.

## Contribution Rules

- Keep German, English and Spanish content in sync.
- Preserve matching translation key order in `config.toml`.
- Use conventional commit messages.
- Edit AI assistant config under `.agents/`, never the `.claude/` or root symlinks.
- Run `zola build` and `./scripts/check-links.py` before committing.
- One slug per post: recurring events carry the year (`pfingstmontag-2027`).

## AI Assistant Config

AI instructions, skills and agents live once under `.agents/` (plain Markdown). Each tool reads that single source through committed symlinks: Codex via root `AGENTS.md`, Claude Code via `CLAUDE.md` and `.claude/`. No build step.

See [CONTRIBUTING.md](./CONTRIBUTING.md) and [`.agents/AGENTS.md`](./.agents/AGENTS.md) for the full agent workflow, voice rules and post-writing guidance.
