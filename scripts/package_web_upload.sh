#!/usr/bin/env bash
set -euo pipefail

out_dir="artifacts"
out_zip="${out_dir}/github-web-upload.zip"

mkdir -p "$out_dir"
rm -f "$out_zip"

zip -r "$out_zip" \
  db \
  docs \
  scripts \
  -x "*/.DS_Store" >/dev/null

echo "Created: $out_zip"
unzip -l "$out_zip" | sed -n '1,120p'
