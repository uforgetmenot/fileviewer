#!/usr/bin/env python3
"""Generate index.json listing selected file types within the working directory."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

CATEGORY_EXTENSIONS = {
  "images": {".png", ".jpg", ".jpeg", ".gif", ".webp"},
  "video": {".mp4", ".webm", ".ogv", ".m4v"},
  "audio": {".mp3", ".wav", ".m4a", ".ogg", ".oga", ".flac", ".aac"},
  "markdown": {".md", ".markdown"},
  "mindmap": set(),  # handled via double-extension detection
  "drawio": {".drawio"},
  "pdf": {".pdf"},
  "word": {".docx"}, # only .docx supported
  "excel": {".xlsx"}, # only .xlsx supported
  "text": {".txt"},
  "slides": {".pptx"}, # only .pptx supported
  "marpit": set(),  # handled via double-extension detection
}

CATEGORY_ORDER = tuple(CATEGORY_EXTENSIONS.keys())
GroupMap = Dict[str, Dict[str, List[str]]]


def categorize_file(path: Path) -> Optional[str]:
  """Return the logical category for a file path if supported."""
  if not path.is_file():
    return None

  name_lower = path.name.lower()
  if name_lower.endswith(".mm.md"):
    return "mindmap"
  if name_lower.endswith(".ppt.md"):
    return "marpit"

  suffix = path.suffix.lower()
  for category, extensions in CATEGORY_EXTENSIONS.items():
    if suffix in extensions:
      return category

  return None


def collect_grouped_files(directory: Path) -> Tuple[GroupMap, Dict[str, int]]:
  """Recursively collect supported files grouped by directory and category."""
  grouped: GroupMap = {}
  totals: Dict[str, int] = {category: 0 for category in CATEGORY_ORDER}

  for path in directory.rglob("*"):
    category = categorize_file(path)
    if not category:
      continue

    rel_path = path.relative_to(directory).as_posix()
    rel_dir = path.parent.relative_to(directory).as_posix()
    dir_key = "." if rel_dir == "." else rel_dir

    grouped.setdefault(dir_key, {}).setdefault(category, []).append(rel_path)
    totals[category] += 1

  for categories in grouped.values():
    for items in categories.values():
      items.sort()

  return grouped, totals


def serialize_groups(grouped: GroupMap, totals: Dict[str, int]) -> dict:
  """Convert grouped data and totals into a JSON-friendly payload."""
  sorted_keys = sorted(grouped.keys(), key=lambda key: (key != ".", key))
  groups = []

  for key in sorted_keys:
    categories = grouped[key]
    category_entries = [
      {"type": category, "files": categories[category], "count": len(categories[category])}
      for category in CATEGORY_ORDER
      if category in categories
    ]
    groups.append({"path": key, "categories": category_entries})

  ordered_totals = {category: totals.get(category, 0) for category in CATEGORY_ORDER}
  return {
    "groups": groups,
    "totalsByType": ordered_totals,
    "totalFiles": sum(ordered_totals.values()),
  }


def main(argv: List[str]) -> int:
  target = Path(argv[1]).expanduser() if len(argv) > 1 else Path.cwd()
  if not target.exists():
    print(f"目标不存在: {target}")
    return 1
  if not target.is_dir():
    print(f"不是目录: {target}")
    return 1

  grouped, totals = collect_grouped_files(target)
  payload = serialize_groups(grouped, totals)
  output_path = target / "index.json"
  try:
    output_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
  except OSError as exc:
    print(f"写入 {output_path.name} 失败: {exc}")
    return 1

  print(f"已生成 {output_path.name}，包含文件数量: {payload.get('totalFiles', 0)}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main(sys.argv))
