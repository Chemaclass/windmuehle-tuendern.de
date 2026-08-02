#!/usr/bin/env bash

# Absolute paths resolved at load time — tests cd into temp dirs.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/new-post.sh"
SEED_IMG="$REPO_ROOT/static/imgs/og-image.jpg"

function set_up() {
  temp_dir=$(mktemp -d)
  original_dir=$(pwd)
  mkdir -p "$temp_dir/content/aktuelles" \
           "$temp_dir/content/en/aktuelles" \
           "$temp_dir/content/es/aktuelles" \
           "$temp_dir/static/imgs/thumbs" \
           "$temp_dir/local/imgs"
  cp "$SEED_IMG" "$temp_dir/local/imgs/photo-a.jpg"
  cp "$SEED_IMG" "$temp_dir/local/imgs/photo-b.jpg"
  cp "$SEED_IMG" "$temp_dir/local/imgs/photo-c.jpg"
  cd "$temp_dir"
}

function tear_down() {
  cd "$original_dir"
  rm -rf "$temp_dir"
}

function test_creates_post_file_with_date_prefix() {
  "$SCRIPT" my-slug -D 2026-05-10 >/dev/null

  assert_file_exists "content/aktuelles/2026-05-10-my-slug.md"
}

function test_creates_en_and_es_post_stubs() {
  "$SCRIPT" my-slug -D 2026-05-10 >/dev/null

  assert_file_exists "content/en/aktuelles/2026-05-10-my-slug.md"
  assert_file_exists "content/es/aktuelles/2026-05-10-my-slug.md"
}

function test_en_and_es_posts_have_translation_markers() {
  "$SCRIPT" my-slug -D 2026-05-10 >/dev/null

  en=$(cat "content/en/aktuelles/2026-05-10-my-slug.md")
  es=$(cat "content/es/aktuelles/2026-05-10-my-slug.md")

  assert_contains "TODO: translate to English" "$en"
  assert_contains "TODO: translate to Spanish" "$es"
}

function test_de_post_has_no_translation_marker() {
  "$SCRIPT" my-slug -D 2026-05-10 >/dev/null

  de=$(cat "content/aktuelles/2026-05-10-my-slug.md")

  assert_not_contains "TODO: translate" "$de"
}

function test_rerun_preserves_existing_en_post() {
  echo "existing EN content" > "content/en/aktuelles/2026-05-10-my-slug.md"
  en_before=$(cat "content/en/aktuelles/2026-05-10-my-slug.md")

  "$SCRIPT" my-slug -D 2026-05-10 >/dev/null

  en_after=$(cat "content/en/aktuelles/2026-05-10-my-slug.md")
  assert_same "$en_before" "$en_after"
  assert_file_exists "content/aktuelles/2026-05-10-my-slug.md"
  assert_file_exists "content/es/aktuelles/2026-05-10-my-slug.md"
}

function test_post_frontmatter_contains_title_description() {
  "$SCRIPT" baustelle -t "Baustelle" -s "Infos zur Baustelle" -D 2026-05-10 >/dev/null

  content=$(cat "content/aktuelles/2026-05-10-baustelle.md")

  assert_contains 'title = "Baustelle"' "$content"
  assert_contains 'description = "Infos zur Baustelle"' "$content"
  assert_contains 'template = "blog-post.html"' "$content"
}

function test_post_frontmatter_omits_date_field() {
  # Date lives in the filename now; Zola derives page.date from it.
  "$SCRIPT" baustelle -t "Baustelle" -s "Infos zur Baustelle" -D 2026-05-10 >/dev/null

  content=$(cat "content/aktuelles/2026-05-10-baustelle.md")

  assert_not_contains 'date =' "$content"
}

function test_post_body_contains_summary_as_intro() {
  "$SCRIPT" baustelle -t "Baustelle" -s "Infos zur Baustelle" -D 2026-05-10 >/dev/null

  # Body text between closing +++ and first <div class="post-images">
  body=$(awk '/^\+\+\+$/{c++;next} c==2' "content/aktuelles/2026-05-10-baustelle.md")

  assert_contains "Infos zur Baustelle" "$body"
}

function test_humanizes_slug_to_title_when_title_omitted() {
  "$SCRIPT" neue-fluegel -D 2026-05-10 >/dev/null

  content=$(cat "content/aktuelles/2026-05-10-neue-fluegel.md")

  assert_contains 'title = "Neue Fluegel"' "$content"
}

function test_optimizes_images_to_static_dir() {
  "$SCRIPT" my-slug -D 2026-05-10 >/dev/null

  assert_file_exists "static/imgs/my-slug/my-slug-01.jpg"
  assert_file_exists "static/imgs/my-slug/my-slug-02.jpg"
  assert_file_exists "static/imgs/my-slug/my-slug-03.jpg"
}

function test_resizes_post_images_to_1200px_width() {
  "$SCRIPT" my-slug -D 2026-05-10 >/dev/null

  width=$(sips -g pixelWidth "static/imgs/my-slug/my-slug-01.jpg" | awk '/pixelWidth/ {print $2}')

  assert_same "1200" "$width"
}

function test_generates_thumbnail_only_for_first_image() {
  # Only the first image is the default extra.image. Additional thumbnails
  # are generated on demand via scripts/make-thumb.sh.
  "$SCRIPT" my-slug -D 2026-05-10 >/dev/null

  assert_file_exists "static/imgs/thumbs/my-slug-01.jpg"
  assert_file_not_exists "static/imgs/thumbs/my-slug-02.jpg"
  assert_file_not_exists "static/imgs/thumbs/my-slug-03.jpg"

  width=$(sips -g pixelWidth "static/imgs/thumbs/my-slug-01.jpg" | awk '/pixelWidth/ {print $2}')
  assert_same "600" "$width"
}

function test_gallery_references_optimized_image_paths() {
  "$SCRIPT" my-slug -D 2026-05-10 >/dev/null

  content=$(cat "content/aktuelles/2026-05-10-my-slug.md")

  assert_contains '/imgs/my-slug/my-slug-01.jpg' "$content"
  assert_contains '/imgs/my-slug/my-slug-02.jpg' "$content"
  assert_contains '<div class="post-images">' "$content"
}

function test_gallery_uses_single_post_images_div() {
  # CSS .post-images is a 2-column grid; multiple divs create orphan rows.
  "$SCRIPT" my-slug -D 2026-05-10 >/dev/null

  count=$(grep -c '<div class="post-images">' "content/aktuelles/2026-05-10-my-slug.md")

  assert_same "1" "$count"
}

function test_frontmatter_extra_image_uses_first_optimized() {
  "$SCRIPT" my-slug -D 2026-05-10 >/dev/null

  content=$(cat "content/aktuelles/2026-05-10-my-slug.md")

  assert_contains 'image = "/imgs/my-slug/my-slug-01.jpg"' "$content"
}

function test_custom_source_dir_option() {
  mkdir -p custom-dir
  cp "$SEED_IMG" custom-dir/x.jpg

  "$SCRIPT" my-slug -d custom-dir -D 2026-05-10 >/dev/null

  assert_file_exists "static/imgs/my-slug/my-slug-01.jpg"
}

function test_fails_when_slug_missing() {
  output=$("$SCRIPT" 2>&1) && status=0 || status=$?

  assert_not_equals "0" "$status"
  assert_contains "slug" "$output"
}

function test_fails_when_slug_invalid_format() {
  output=$("$SCRIPT" "Bad Slug" -D 2026-05-10 2>&1) && status=0 || status=$?

  assert_not_equals "0" "$status"
  assert_contains "kebab-case" "$output"
}

function test_fails_when_date_invalid_format() {
  output=$("$SCRIPT" my-slug -D "10-05-2026" 2>&1) && status=0 || status=$?

  assert_not_equals "0" "$status"
  assert_contains "YYYY-MM-DD" "$output"
}

function test_fails_when_source_dir_missing() {
  output=$("$SCRIPT" my-slug -d does-not-exist -D 2026-05-10 2>&1) && status=0 || status=$?

  assert_not_equals "0" "$status"
  assert_contains "does not exist" "$output"
}

function test_fails_when_source_dir_has_no_images() {
  mkdir -p empty-dir

  output=$("$SCRIPT" my-slug -d empty-dir -D 2026-05-10 2>&1) && status=0 || status=$?

  assert_not_equals "0" "$status"
  assert_contains "no images" "$output"
}

function test_rerun_leaves_all_posts_untouched_when_all_exist() {
  "$SCRIPT" my-slug -D 2026-05-10 >/dev/null

  # Mutate DE so we can prove the re-run does not overwrite it.
  echo "MUTATED" >> "content/aktuelles/2026-05-10-my-slug.md"
  de_before=$(cat "content/aktuelles/2026-05-10-my-slug.md")

  output=$("$SCRIPT" my-slug -D 2026-05-10 2>&1)

  assert_contains "Nothing new to do" "$output"
  assert_contains "Untouched" "$output"

  de_after=$(cat "content/aktuelles/2026-05-10-my-slug.md")
  assert_same "$de_before" "$de_after"
}

function test_rerun_creates_only_missing_language_posts() {
  # First run creates all three.
  "$SCRIPT" my-slug -D 2026-05-10 >/dev/null

  # Remove EN and ES only; keep DE with a mutation we can detect.
  echo "KEEP" >> "content/aktuelles/2026-05-10-my-slug.md"
  de_before=$(cat "content/aktuelles/2026-05-10-my-slug.md")
  rm "content/en/aktuelles/2026-05-10-my-slug.md" \
     "content/es/aktuelles/2026-05-10-my-slug.md"

  output=$("$SCRIPT" my-slug -D 2026-05-10 2>&1)

  assert_contains "Created:" "$output"
  assert_file_exists "content/en/aktuelles/2026-05-10-my-slug.md"
  assert_file_exists "content/es/aktuelles/2026-05-10-my-slug.md"

  de_after=$(cat "content/aktuelles/2026-05-10-my-slug.md")
  assert_same "$de_before" "$de_after"
}

function seed_de_post() {
  # $1 = filename date. Handcrafted DE post used by the enrich/guard tests.
  mkdir -p content/aktuelles
  cat > "content/aktuelles/${1}-my-slug.md" <<'EOF'
+++
title = "Handgepflegter Titel"
description = "Handgepflegte Beschreibung"
template = "blog-post.html"

[extra]
image = "/imgs/my-slug/my-slug-03.jpg"
+++

body
EOF
}

function test_rerun_inherits_frontmatter_from_existing_de() {
  # Without -D the run enriches the existing post: EN/ES stubs take its
  # title/description, extra.image and date (from the filename).
  seed_de_post 2026-04-17

  "$SCRIPT" my-slug >/dev/null

  en=$(cat "content/en/aktuelles/2026-04-17-my-slug.md")
  assert_contains 'title = "Handgepflegter Titel"' "$en"
  assert_contains 'description = "Handgepflegte Beschreibung"' "$en"
  assert_contains 'image = "/imgs/my-slug/my-slug-03.jpg"' "$en"
  assert_file_exists "content/es/aktuelles/2026-04-17-my-slug.md"
}

function test_enrich_run_names_the_post_it_edits() {
  seed_de_post 2026-04-17

  output=$("$SCRIPT" my-slug 2>&1)

  assert_contains "Enriching existing post" "$output"
  assert_contains "2026-04-17-my-slug.md" "$output"
}

function test_fails_when_date_conflicts_with_slug_owner() {
  # A slug belongs to one post. Asking for another date means a new post,
  # which silently became an enrich run before this guard existed.
  seed_de_post 2026-04-17

  output=$("$SCRIPT" my-slug -D 2027-05-10 2>&1) && status=0 || status=$?

  assert_not_equals "0" "$status"
  assert_contains "already belongs" "$output"
  assert_contains "my-slug-2027" "$output"
}

function test_same_date_for_slug_owner_still_enriches() {
  seed_de_post 2026-04-17

  output=$("$SCRIPT" my-slug -D 2026-04-17 2>&1) && status=0 || status=$?

  assert_equals "0" "$status"
  assert_file_exists "content/en/aktuelles/2026-04-17-my-slug.md"
}

function test_fails_when_year_scoped_siblings_exist() {
  # The bare slug is free, but the event family already carries years.
  seed_de_post 2025-06-09
  mv "content/aktuelles/2025-06-09-my-slug.md" \
     "content/aktuelles/2025-06-09-my-slug-2025.md"

  output=$("$SCRIPT" my-slug -D 2027-06-01 2>&1) && status=0 || status=$?

  assert_not_equals "0" "$status"
  assert_contains "recurring event" "$output"
  assert_contains "my-slug-2027" "$output"
}

function test_rejected_slug_writes_nothing() {
  seed_de_post 2026-04-17

  "$SCRIPT" my-slug -D 2027-05-10 >/dev/null 2>&1 || true

  assert_file_not_exists "content/aktuelles/2027-05-10-my-slug.md"
  assert_file_not_exists "content/en/aktuelles/2026-04-17-my-slug.md"
  assert_directory_not_exists "static/imgs/my-slug"
}

function test_rerun_reuses_existing_optimized_images_without_source_dir() {
  "$SCRIPT" my-slug -D 2026-05-10 >/dev/null

  # Remove EN stub and delete the source dir; images should be reused from
  # static/imgs/my-slug/, so the second run must still succeed.
  rm "content/en/aktuelles/2026-05-10-my-slug.md"
  rm -rf local

  output=$("$SCRIPT" my-slug -D 2026-05-10 2>&1)

  assert_contains "Reusing" "$output"
  assert_file_exists "content/en/aktuelles/2026-05-10-my-slug.md"
}
