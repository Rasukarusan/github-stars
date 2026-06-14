#!/usr/bin/env bash
# GitHubのstar一覧を取得し、categories.json の分類を当てて stars.json を生成する。
# 使い方: ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "▶ starを取得中 (gh api user/starred)..." >&2
gh api user/starred --paginate \
  -q '.[] | {name: .full_name, lang: (.language // ""), desc: ((.description // "") | gsub("[\r\n\t]"; " ")), stars: .stargazers_count, url: .html_url}' \
  | jq -s '.' > raw.json

TOTAL=$(jq 'length' raw.json)
echo "▶ ${TOTAL}件取得。分類を適用中..." >&2

UPDATED=$(date '+%Y-%m-%d %H:%M')

jq -n \
  --arg updated "$UPDATED" \
  --slurpfile repos raw.json \
  --slurpfile cats categories.json \
  --slurpfile meta category-meta.json '
  ($cats[0]) as $c
  | ($meta[0]) as $m
  | ($repos[0] | map(. + {category: ($c[.name] // "uncategorized")})) as $r
  | {
      updated_at: $updated,
      total: ($r | length),
      categories: (
        $r
        | group_by(.category)
        | map(
            (.[0].category) as $k
            | {
                key: $k,
                label: ($m[$k].label // ($k | if . == "uncategorized" then "未分類" else . end)),
                emoji: ($m[$k].emoji // "❓"),
                order: ($m[$k].order // 998),
                count: length,
                repos: (sort_by(-.stars))
              }
          )
        | sort_by(.order)
      )
    }
  ' > stars.json

# 未分類の検知
UNCAT=$(jq -r '.categories[] | select(.key=="uncategorized") | .repos[].name' stars.json 2>/dev/null || true)
if [ -n "$UNCAT" ]; then
  echo "⚠ 未分類のリポジトリがあります（categories.json に追記してください）:" >&2
  echo "$UNCAT" | sed 's/^/   - /' >&2
fi

echo "✅ stars.json を生成しました（${TOTAL}件）" >&2
