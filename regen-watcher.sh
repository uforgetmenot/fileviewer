#!/usr/bin/env bash
set -euo pipefail

WATCH_DIR=${WATCH_DIR:-/workspace}
TARGET_DIR=${TARGET_DIR:-$WATCH_DIR}
GENERATE_SCRIPT=${GENERATE_SCRIPT:-$WATCH_DIR/generate.py}
TEMPLATE_DIR=${TEMPLATE_DIR:-/opt/template}
SUPPORTED_PATTERN='\.(png|jpg|jpeg|gif|webp|md|drawio|pdf|xlsx|docx|txt|pptx|mp4|webm|ogv|m4v|mp3|wav|m4a|ogg|oga|flac|aac)$'
SITE_NAME=${SITE_NAME:-文件浏览器}

if [[ ! -d "$WATCH_DIR" ]]; then
  echo "监控目录不存在: $WATCH_DIR" >&2
  exit 1
fi

seed_default_content() {
  [[ -d "$TEMPLATE_DIR" ]] || return

  local items=(assets index.html generate.py)
  for name in "${items[@]}"; do
    local src="$TEMPLATE_DIR/$name"
    local dest="$WATCH_DIR/$name"
    [[ -e "$dest" ]] && continue
    if [[ -d "$src" ]]; then
      echo "未检测到 $dest，复制模板目录 $name"
      cp -r "$src" "$dest"
    elif [[ -f "$src" ]]; then
      echo "未检测到 $dest，复制模板文件 $name"
      cp "$src" "$dest"
    fi
  done
}

configure_site_name() {
  local target_file="$WATCH_DIR/index.html"
  [[ -f "$target_file" ]] || return

  python3 - "$target_file" "$SITE_NAME" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
site_name = sys.argv[2]
text = path.read_text(encoding="utf-8")

title_pattern = re.compile(r"(<title>)(.*?)(</title>)", re.S)
brand_pattern = re.compile(r'(<a[^>]*class="header__brand"[^>]*>\s*(?:<svg.*?</svg>\s*))([^<]+)', re.S)

updated = title_pattern.sub(lambda m: f"{m.group(1)}{site_name}{m.group(3)}", text, count=1)
updated = brand_pattern.sub(lambda m: f"{m.group(1)}{site_name}", updated, count=1)

if updated != text:
    path.write_text(updated, encoding="utf-8")
PY
}

seed_default_content
configure_site_name

if [[ ! -f "$GENERATE_SCRIPT" ]]; then
  echo "未找到 generate.py: $GENERATE_SCRIPT" >&2
  exit 1
fi

run_generate() {
  echo "运行 generate.py 更新 index.json..."
  python3 "$GENERATE_SCRIPT" "$TARGET_DIR" || echo "generate.py 执行失败" >&2
}

# 初始生成一次，确保 index.json 可用
run_generate

# 递归监听文件创建、删除和写入事件
inotifywait -m -r \
  --event create --event delete --event moved_to --event moved_from --event close_write \
  --format '%w%f::%e' --quiet --exclude '((^|/)\.git(/|$))|index\.json$' \
  "$WATCH_DIR" | while IFS= read -r event; do
    filepath=${event%%::*}
    events=${event##*::}

    # 忽略目录事件
    if [[ "$events" == *"ISDIR"* ]]; then
      continue
    fi

    filename=$(basename -- "$filepath")
    lower_name=${filename,,}

    # 忽略 README.md
    if [[ "$filename" == "README.md" ]]; then
      continue
    fi

    if [[ $lower_name =~ $SUPPORTED_PATTERN ]]; then
      echo "检测到 ${filename} 的事件 ($events)，重新生成..."
      run_generate
    fi
  done
