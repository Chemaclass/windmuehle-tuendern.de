#!/usr/bin/env python3
"""Validate data/fuehrungen.toml shape and field values."""

import re
import sys
from pathlib import Path

try:
    import tomllib  # Python 3.11+
except ModuleNotFoundError:
    try:
        import tomli as tomllib  # type: ignore
    except ModuleNotFoundError:
        sys.exit(
            "validate-fuehrungen.py needs Python 3.11+ or the tomli package.\n"
            "Run ./scripts/setup.sh to install it."
        )

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "fuehrungen.toml"

KINDS = {"public", "private", "event"}
STATUSES = {"free", "booked", "cancelled"}
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
TIME_RE = re.compile(r"^\d{2}:\d{2}$")


def validate() -> list[str]:
    errors: list[str] = []
    with open(DATA, "rb") as f:
        cfg = tomllib.load(f)

    slots = cfg.get("slots", [])
    if not isinstance(slots, list):
        return ["root 'slots' must be a TOML array of tables"]

    for i, slot in enumerate(slots, 1):
        prefix = f"slot #{i}"
        date = str(slot.get("date", ""))
        time = str(slot.get("time", ""))
        kind = slot.get("kind")
        status = slot.get("status")
        guide = slot.get("guide")
        duration_min = slot.get("duration_min")
        title = slot.get("title")
        location = slot.get("location")
        free_entry = slot.get("free_entry")

        if not DATE_RE.match(date):
            errors.append(f"{prefix}: invalid date '{date}' (expected YYYY-MM-DD)")
        if not TIME_RE.match(time):
            errors.append(f"{prefix}: invalid time '{time}' (expected HH:MM)")
        if kind not in KINDS:
            errors.append(f"{prefix}: invalid kind '{kind}' (expected {sorted(KINDS)})")
        if status not in STATUSES:
            errors.append(
                f"{prefix}: invalid status '{status}' (expected {sorted(STATUSES)})"
            )
        if kind == "private" and status == "free":
            errors.append(f"{prefix}: private slot cannot have status 'free'")
        if kind == "event" and not (isinstance(title, str) and title.strip()):
            errors.append(f"{prefix}: event slot requires a non-empty 'title'")
        if title is not None and not isinstance(title, str):
            errors.append(f"{prefix}: title must be string, got {title!r}")
        if location is not None and not isinstance(location, str):
            errors.append(f"{prefix}: location must be string, got {location!r}")
        if free_entry is not None and not isinstance(free_entry, bool):
            errors.append(f"{prefix}: free_entry must be boolean, got {free_entry!r}")
        if duration_min is not None and not isinstance(duration_min, int):
            errors.append(f"{prefix}: duration_min must be integer, got {duration_min!r}")
        if duration_min is not None and isinstance(duration_min, int) and duration_min <= 0:
            errors.append(f"{prefix}: duration_min must be positive")
        if guide is not None and not isinstance(guide, str):
            errors.append(f"{prefix}: guide must be string, got {guide!r}")
        link = slot.get("link")
        if link is not None and not isinstance(link, str):
            errors.append(f"{prefix}: link must be string, got {link!r}")

    return errors


def main() -> int:
    if not DATA.exists():
        print(f"ERROR: {DATA} not found", file=sys.stderr)
        return 2

    errors = validate()
    if errors:
        print("Fuehrungen data validation FAILED:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    with open(DATA, "rb") as f:
        cfg = tomllib.load(f)
    print(f"OK: {len(cfg.get('slots', []))} slot(s) validated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
