---
description: Run `zola build` and report errors or success for the Windmühle Tündern site. Use when the user says "build check", "does it build", "verify build", "is the site building", "compile the site", or invokes /build-check. Auto-trigger after any edit to templates, sass, content, config.toml, or data/*.toml when the user wants to confirm the site still builds.
argument-hint: "(no arguments needed)"
---

# Build Check

Run `zola build` from the project root and report the result.

## Steps

1. `zola build`
2. If it succeeds, report `Build passed` with the page count summary Zola prints (`Creating N pages and M sections`).
3. If it fails, show the offending error lines, identify the file and line if Zola reports them, and suggest the fix.
4. Then `./scripts/check-links.py`. Zola resolves no link and no image path, so a green build proves nothing about them. Report the broken targets it lists together with the pages referencing them.

## When to fail loudly

- Tera template errors (missing keys, bad syntax, type mismatch).
- Frontmatter parse errors.
- Missing translation key referenced by `trans(key=..., lang=...)`.
- Broken internal links or shortcodes (`check-links.py`, not `zola build`).
- Image paths that no longer exist after a rename (`check-links.py`).

If the error is opaque, re-run with `RUST_LOG=debug zola build 2>&1 | tail -50` for more context.
