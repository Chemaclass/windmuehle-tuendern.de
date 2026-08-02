---
description: Scaffold a new blog post for the Windmühle Tündern site in DE / EN / ES under content/aktuelles/. Optimizes images and generates a homepage thumbnail. Use when the user says "new post", "new blog post", "add an Aktuelles post", "create a post", "neuer Blogpost", or invokes /new-post.
argument-hint: "<slug> [-t title] [-s summary] [-D YYYY-MM-DD] [-d local/imgs/]"
---

# Create or enrich a blog post

Scaffold a new post under `content/aktuelles/` (DE), `content/en/aktuelles/` (EN) and `content/es/aktuelles/` (ES). `scripts/new-post.sh` automates image optimization and trilingual file generation. Scripts are a starting point, not a constraint: when the scaffold does not fit the content, restructure freely.

## Inputs to ask for if not provided

- Slug (kebab-case). Recurring events carry the year: `pfingstmontag-2027`, not `pfingstmontag`.
- Title (defaults to humanized slug)
- Summary / description (frontmatter + fallback body)
- Date (defaults to today)
- Source image directory (defaults to `local/imgs/`)

## Steps

1. Drop source images into `local/imgs/` (gitignored) if not already there.
2. Scaffold: `./scripts/new-post.sh <slug> -t "Title" -s "Description." -D YYYY-MM-DD`
3. Look at the images yourself (Read the jpgs) before writing text. Run `sips -g pixelWidth -g pixelHeight <path>` to know orientation.
4. Draft the DE post end-to-end: title, description, sectioned body with `##` headings, image groups. Don't dump all images into one div.
5. Mirror the structure into EN and ES. Translate fully if confident; otherwise leave the `<!-- TODO: translate -->` marker and translate the image structure only. Keep image paths identical across languages.
6. Optional: `./scripts/make-thumb.sh <image-path>` to swap the hero (handles all three language files + regenerates the thumbnail).
7. `zola build` to verify.
8. Commit conventional (`feat: add <title> post`). Summarize the sections, image grouping, and voice choices you made.

## Image layout

`.post-images` is a 2-column grid. Group images into `<div class="post-images">` blocks of even size (even groups avoid orphan rows). Split long galleries into multiple sections with H2 headings between them when the images tell a story.

Single-image posts — pick by orientation:

| Case | Layout | `hide_hero` | Body markup |
|---|---|---|---|
| horizontal (w ≥ h) | full width below text | `true` | text first, then `<div class="post-images"><img …></div>` at the bottom |
| vertical (w < h) | image left, text right | `true` | `<div class="post-split"><img …><div class="post-split-text">…</div></div>` |
| 2+ images | `.post-images` grids, group evenly | omit (hero = banner) | group logically |

- `hide_hero = true` whenever the only/primary image is already in the body (avoids a duplicate hero crop).
- Photo credit: `extra.image_credit = "Foto: <name>"` (figcaption when hero shows; else inline `<em>Foto: <name></em>` in `.post-split-text`).
- Event-announcement posts: wrap the date/time line in `<p class="event-when"><strong>Wann/When/Cuándo:</strong> …</p>`.
- Always keep `extra.image` set (homepage news thumbnail) even when the hero is hidden. Pick the most striking photo.
- Image alt text is intentionally omitted on gallery images. Don't add it back.
- Structure rhythm reference: `content/aktuelles/2026-04-17-einweihung-der-windmuehle.md`.

## Voice and tone (strict)

Village association website. Plain, direct, warm, German-native. Not marketing copy, not a press release.

- No AI tells: no em/en dashes (`—` / `–`), no "it was finally time", no "wir dürfen mit Stolz verkünden", no flowery metaphors. Use commas and periods.
- Short sentences win (8-15 words average). No filler adjectives (`beeindruckend`, `stimmungsvoll`, `unvergesslich`).
- First-person plural (`wir`) is the house voice. Dates in full: `am 17. April`, not `17.04.`.
- Proper nouns never translated: Tündern, Windmühle Tündern, Förderverein Windmühle Tündern e.V.

## Conventions

- Filenames `YYYY-MM-DD-<slug>.md`. Zola derives `page.date` from the filename, so frontmatter has no `date` field.
- A slug belongs to exactly one post. Recurring events (Pfingstmontag, Mühlentag, Weihnachten, Konzerte) carry the year as a suffix from the first occurrence on: `pfingstmontag-2027`, `weihnachten-2027`. One-off news posts do not. `new-post.sh` refuses a slug another post owns, and refuses a bare slug when year-scoped siblings exist.
- Frontmatter requires `title`, `description`, `template = "blog-post.html"`, `[extra] image`.
- Every post needs a matching thumbnail in `static/imgs/thumbs/<basename>.jpg` (the script generates it).

## When NOT to use this skill

- To swap only the hero image of an existing post, use `scripts/make-thumb.sh`.
- To translate an existing post, edit the EN / ES files directly; this skill scaffolds stubs only.
