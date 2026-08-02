#!/usr/bin/env bash

# Emergency offline script to create a new aktuelles post (DE + EN + ES).
# Optimizes images, generates a thumbnail, scaffolds the markdown files.
# Safe to re-run: existing language files are left untouched; only missing
# ones are created. Existing optimized images are reused when present.
#
# A slug belongs to exactly one post. Recurring events carry the year
# (pfingstmontag-2027, weihnachten-2027); one-off news posts do not.
#
# Usage:
#   ./scripts/new-post.sh <slug> [options]
#
# Options:
#   -d, --dir <path>          Source image directory (default: local/imgs/)
#   -t, --title <string>      Post title (default: slug humanized)
#   -s, --summary <string>    Description for frontmatter (default: title)
#   -D, --date <YYYY-MM-DD>   Post date (default: today)
#   -h, --help                Show this help
#
# Passing -D for a slug that another post already owns is an error: that is
# a new post and needs its own slug. Re-run without -D to enrich the
# existing post instead.
#
# Example:
#   ./scripts/new-post.sh fluegel-montage -t "Flügelmontage" -s "Die neuen Flügel wurden montiert."

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/optimize.sh
source "${SCRIPT_DIR}/lib/optimize.sh"

SRC_DIR="local/imgs/"
SLUG=""
TITLE=""
SUMMARY=""
DATE="$(date +%Y-%m-%d)"
DATE_EXPLICIT=0

# Print the header comment block (from line 3 to the first non-comment line).
usage() {
  awk 'NR < 3 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dir)     SRC_DIR="$2"; shift 2 ;;
    -t|--title)   TITLE="$2"; shift 2 ;;
    -s|--summary) SUMMARY="$2"; shift 2 ;;
    -D|--date)    DATE="$2"; DATE_EXPLICIT=1; shift 2 ;;
    -h|--help)    usage 0 ;;
    -*)           echo "Unknown option: $1" >&2; usage 1 ;;
    *)            if [[ -z "$SLUG" ]]; then SLUG="$1"; else echo "Too many args" >&2; usage 1; fi; shift ;;
  esac
done

if [[ -z "$SLUG" ]]; then
  echo "Error: <slug> required" >&2
  usage 1
fi

if ! [[ "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "Error: slug must be lowercase kebab-case (a-z, 0-9, -)" >&2
  exit 1
fi

if ! [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: date must be YYYY-MM-DD" >&2
  exit 1
fi

# Humanize slug for default title
humanize() {
  echo "$1" | tr '-' ' ' | awk '{for (i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1'
}

# Return the path to the existing post in $1 whose filename ends with -<slug>.md.
# Empty if none. Exits with an error if more than one matches.
find_existing_post() {
  local dir="$1"
  shopt -s nullglob
  local matches=("$dir"/*-"${SLUG}".md)
  shopt -u nullglob
  if [[ ${#matches[@]} -eq 0 ]]; then echo ""; return; fi
  if [[ ${#matches[@]} -gt 1 ]]; then
    echo "Error: multiple posts match slug '$SLUG' in $dir:" >&2
    printf '  %s\n' "${matches[@]}" >&2
    exit 1
  fi
  echo "${matches[0]}"
}

# Read `key = "value"` from the frontmatter of $1. Empty if missing.
read_fm_string() {
  awk -F'"' -v key="$2" '$0 ~ "^" key " = "{print $2; exit}' "$1"
}

# Extract date from a post filename of the form YYYY-MM-DD-slug.md.
filename_date() {
  local base
  base=$(basename "$1")
  echo "${base:0:10}"
}

IMG_DIR="static/imgs/${SLUG}"
THUMB_DIR="static/imgs/thumbs"

EXISTING_DE=$(find_existing_post "content/aktuelles")
EXISTING_EN=$(find_existing_post "content/en/aktuelles")
EXISTING_ES=$(find_existing_post "content/es/aktuelles")

EXISTING_ANY="${EXISTING_DE:-${EXISTING_EN:-$EXISTING_ES}}"
YEAR="${DATE%%-*}"

# Refuse ambiguous slugs before anything is written to disk. Without this the
# script would silently switch to enrich mode: inherit the old post's date,
# title and photos, then report "nothing to do" on what the caller meant as a
# new post.
if [[ -n "$EXISTING_ANY" ]]; then
  existing_date=$(filename_date "$EXISTING_ANY")
  if [[ $DATE_EXPLICIT -eq 1 && "$existing_date" != "$DATE" ]]; then
    echo "Error: slug '${SLUG}' already belongs to ${EXISTING_ANY} (dated ${existing_date})." >&2
    echo "       Recurring events carry the year: try '${SLUG}-${YEAR}'." >&2
    echo "       To edit that existing post instead, re-run without -D." >&2
    exit 1
  fi
  echo "→ Enriching existing post ${EXISTING_ANY} (dated ${existing_date})"
else
  # No post owns the bare slug, but year-scoped siblings mean this is an
  # event family. A bare slug would break the family's naming.
  shopt -s nullglob
  SIBLINGS=(content/aktuelles/*-"${SLUG}"-[0-9][0-9][0-9][0-9].md)
  shopt -u nullglob
  if [[ ${#SIBLINGS[@]} -gt 0 ]]; then
    echo "Error: '${SLUG}' is a recurring event, its posts carry the year:" >&2
    printf '         %s\n' "${SIBLINGS[@]}" >&2
    echo "       Use '${SLUG}-${YEAR}'." >&2
    exit 1
  fi
fi

POST_DE="${EXISTING_DE:-content/aktuelles/${DATE}-${SLUG}.md}"
POST_EN="${EXISTING_EN:-content/en/aktuelles/${DATE}-${SLUG}.md}"
POST_ES="${EXISTING_ES:-content/es/aktuelles/${DATE}-${SLUG}.md}"

# Inherit frontmatter from the DE post when it exists, so newly-created
# EN/ES stubs stay aligned with whatever the user has since edited.
if [[ -n "$EXISTING_DE" ]]; then
  de_title=$(read_fm_string "$EXISTING_DE" "title")
  de_desc=$(read_fm_string "$EXISTING_DE" "description")
  de_date=$(filename_date "$EXISTING_DE")
  de_image=$(read_fm_string "$EXISTING_DE" "image")
  [[ -n "$de_title" ]] && TITLE="$de_title"
  [[ -n "$de_desc" ]]  && SUMMARY="$de_desc"
  [[ -n "$de_date" ]]  && DATE="$de_date"
  EXTRA_IMAGE_OVERRIDE="$de_image"
else
  [[ -z "$TITLE" ]]   && TITLE="$(humanize "$SLUG")"
  [[ -z "$SUMMARY" ]] && SUMMARY="$TITLE"
  EXTRA_IMAGE_OVERRIDE=""
fi

# Recompute fallback paths after a possible DATE inherit from DE, so newly
# created EN/ES stubs line up with the DE post's filename date prefix.
POST_DE="${EXISTING_DE:-content/aktuelles/${DATE}-${SLUG}.md}"
POST_EN="${EXISTING_EN:-content/en/aktuelles/${DATE}-${SLUG}.md}"
POST_ES="${EXISTING_ES:-content/es/aktuelles/${DATE}-${SLUG}.md}"

mkdir -p "$IMG_DIR" "$THUMB_DIR" \
         "$(dirname "$POST_EN")" "$(dirname "$POST_ES")"

# Collect existing optimized images. When present, skip source optimization
# entirely so re-runs don't require the source directory to still be around.
shopt -s nullglob
EXISTING_OPTIMIZED=("$IMG_DIR"/"${SLUG}"-*.jpg)
shopt -u nullglob

OPTIMIZED_NAMES=()
IMAGES_REUSED=0

if [[ ${#EXISTING_OPTIMIZED[@]} -gt 0 ]]; then
  IFS=$'\n' EXISTING_OPTIMIZED=($(printf '%s\n' "${EXISTING_OPTIMIZED[@]}" | sort))
  unset IFS
  for p in "${EXISTING_OPTIMIZED[@]}"; do
    OPTIMIZED_NAMES+=("$(basename "$p")")
  done
  IMAGES_REUSED=1
  echo "→ Reusing ${#OPTIMIZED_NAMES[@]} existing optimized image(s) in $IMG_DIR/"
  if [[ -d "$SRC_DIR" ]]; then
    shopt -s nullglob nocaseglob
    ignored_src=("$SRC_DIR"/*.{jpg,jpeg,png,heic})
    shopt -u nocaseglob
    shopt -u nullglob
    if [[ ${#ignored_src[@]} -gt 0 ]]; then
      echo "  ${#ignored_src[@]} image(s) in $SRC_DIR are ignored. Delete $IMG_DIR/ to re-import them."
    fi
  fi
else
  if [[ ! -d "$SRC_DIR" ]]; then
    echo "Error: source dir '$SRC_DIR' does not exist and no existing images in $IMG_DIR/" >&2
    exit 1
  fi

  # Collect source images (jpg/jpeg/png/heic), case-insensitive, sorted
  shopt -s nullglob nocaseglob
  SRC_IMAGES=()
  for f in "$SRC_DIR"/*.{jpg,jpeg,png,heic}; do
    [[ -f "$f" ]] && SRC_IMAGES+=("$f")
  done
  shopt -u nocaseglob
  shopt -u nullglob

  if [[ ${#SRC_IMAGES[@]} -eq 0 ]]; then
    echo "Error: no images found in '$SRC_DIR' (jpg/jpeg/png/heic)" >&2
    exit 1
  fi

  IFS=$'\n' SRC_IMAGES=($(printf '%s\n' "${SRC_IMAGES[@]}" | sort))
  unset IFS

  echo "→ Found ${#SRC_IMAGES[@]} image(s) in $SRC_DIR"
  i=1
  for src in "${SRC_IMAGES[@]}"; do
    num="$(printf '%02d' "$i")"
    dest_name="${SLUG}-${num}.jpg"
    dest_path="${IMG_DIR}/${dest_name}"
    echo "  [${num}] $(basename "$src") → $dest_path"
    optimize_image "$src" "$dest_path"
    OPTIMIZED_NAMES+=("$dest_name")
    i=$((i+1))
  done
fi

# Pick extra.image: inherit from DE if it exists, else use the first image.
FIRST_IMG="${OPTIMIZED_NAMES[0]}"
EXTRA_IMAGE="${EXTRA_IMAGE_OVERRIDE:-/imgs/${SLUG}/${FIRST_IMG}}"

# Ensure the thumbnail for the effective extra.image exists.
thumb_stem=$(basename "$EXTRA_IMAGE"); thumb_stem="${thumb_stem%.*}"
THUMB_FILE="${THUMB_DIR}/${thumb_stem}.jpg"
THUMB_CREATED=0
if [[ ! -f "$THUMB_FILE" ]]; then
  # Source for the thumb: prefer the optimized file on disk.
  thumb_src="static${EXTRA_IMAGE}"
  if [[ ! -f "$thumb_src" ]]; then
    thumb_src="${IMG_DIR}/${FIRST_IMG}"
  fi
  echo "→ Generating thumbnail: $THUMB_FILE"
  make_thumb "$thumb_src" "$THUMB_FILE"
  THUMB_CREATED=1
fi

# Build gallery markdown: single <div class="post-images">. The grid is
# 2-column; splitting into multiple divs produces orphan rows and oversized
# gaps. Split manually after editing if logical sections are needed.
build_gallery() {
  echo ""
  echo "<div class=\"post-images\">"
  for name in "${OPTIMIZED_NAMES[@]}"; do
    echo "  <img src=\"/imgs/${SLUG}/${name}\">"
  done
  echo "</div>"
}

GALLERY="$(build_gallery)"

# Write a post file with the given language marker in the body.
write_post() {
  local path="$1" marker="$2"
  cat > "$path" <<EOF
+++
title = "${TITLE}"
description = "${SUMMARY}"
template = "blog-post.html"

[extra]
image = "${EXTRA_IMAGE}"
+++

${marker}${SUMMARY}
${GALLERY}
EOF
}

CREATED=()
UNTOUCHED=()

maybe_write() {
  local path="$1" marker="$2"
  if [[ -f "$path" ]]; then
    UNTOUCHED+=("$path")
  else
    write_post "$path" "$marker"
    CREATED+=("$path")
  fi
}

maybe_write "$POST_DE" ""
maybe_write "$POST_EN" "<!-- TODO: translate to English -->
"
maybe_write "$POST_ES" "<!-- TODO: translate to Spanish -->
"

echo ""
echo "Summary:"
if [[ ${#CREATED[@]} -gt 0 ]]; then
  echo "  Created:"
  printf '    %s\n' "${CREATED[@]}"
else
  echo "  Created:       (none)"
fi
if [[ ${#UNTOUCHED[@]} -gt 0 ]]; then
  echo "  Untouched:"
  printf '    %s\n' "${UNTOUCHED[@]}"
fi
if [[ $IMAGES_REUSED -eq 1 ]]; then
  echo "  Images:        reused ${#OPTIMIZED_NAMES[@]} existing in $IMG_DIR/"
else
  echo "  Images:        optimized ${#OPTIMIZED_NAMES[@]} new into $IMG_DIR/"
fi
if [[ $THUMB_CREATED -eq 1 ]]; then
  echo "  Thumbnail:     generated $THUMB_FILE"
else
  echo "  Thumbnail:     untouched $THUMB_FILE"
fi

if [[ ${#CREATED[@]} -eq 0 ]]; then
  echo ""
  echo "Nothing new to do — all three language files already exist."
  exit 0
fi

echo ""
echo "Next steps:"
echo "  1. Edit $POST_DE"
echo "  2. Translate $POST_EN and $POST_ES (remove the TODO marker)"
echo "  3. Run: zola build"
