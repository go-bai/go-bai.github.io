#!/bin/bash

CONTENT_DIR="content"
INDEX_FILE="$CONTENT_DIR/_index.md"

# Start writing the new index content
cat <<EOF > "$INDEX_FILE"
---
title: Home
---

\`gobai\`的简约博客:

<div style="height: 104px; position: relative;">
  <div id="loading" style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); display: block;">
    <div class="spinner" style="width: 40px; height: 40px; border: 4px solid rgba(0, 0, 0, 0.1); border-radius: 50%; border-top-color: #09f; animation: spin 1s linear infinite;"></div>
  </div>
  <img src="http://ghchart.rshah.org/go-bai" alt="go-bai's github chart" style="width: 100%; height: 100%; object-fit: contain;" onload="document.getElementById('loading').style.display='none'" onerror="document.getElementById('loading').innerHTML='加载失败'"/>

  <style>
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
  </style>
</div>

------

## ✏️ 随笔

EOF

# Temporary files to store unsorted entries
TEMP_NOTES=$(mktemp)
TEMP_BLOG=$(mktemp)

# Function to extract title and date from a markdown file
extract_metadata() {
  local file="$1"
  local title=$(grep -m 1 "^title:" "$file" | sed 's/title:[[:space:]]*"\(.*\)"/\1/')
  local date=$(grep -m 1 "^date:" "$file" | sed 's/date:[[:space:]]*\([0-9-]*\).*/\1/')
  echo "$date|$title|$file"
}

# Collect metadata from all markdown files, excluding _index.md
for file in $(find "$CONTENT_DIR" -name "*.md" ! -name "_index.md"); do
  if [[ -f "$file" ]]; then
    # Skip files in about and links directories
    if [[ "$file" == *"/about/"* ]] || [[ "$file" == *"/links/"* ]]; then
      continue
    fi
    # Check if file is in the 'notes' directory
    if [[ "$file" == *"/notes/"* ]]; then
      extract_metadata "$file" >> "$TEMP_NOTES"
    else
      extract_metadata "$file" >> "$TEMP_BLOG"
    fi
  fi
done

# Sort and output notes entries
sort -r "$TEMP_NOTES" | while IFS="|" read -r date title file; do
  filename=$(basename "$file" .md)
  echo "- $date [${title}](/notes/${filename}/)" >> "$INDEX_FILE"
done

# Add blog section
cat <<EOF >> "$INDEX_FILE"

------

## 📝 博客文章

EOF

# Sort and output blog entries
sort -r "$TEMP_BLOG" | while IFS="|" read -r date title file; do
  filename=$(basename "$file" .md)
  echo "- $date [${title}](/posts/${filename}/)" >> "$INDEX_FILE"
done

# Clean up temporary files
rm "$TEMP_NOTES" "$TEMP_BLOG"

echo "博客目录已生成并更新到 $INDEX_FILE"