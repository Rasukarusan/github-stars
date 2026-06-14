#!/usr/bin/env bash
# GitHubのstarを取得し、categories.json の分類を当てて stars.json を生成する。
#
# 既定は「増分モード」: 直近100件(star日付の新しい順)だけ取得し、手元の stars.json に
#   マージする。前回同期から100件以上starしていない限り新規は確実に拾える。API負荷は1リクエスト。
# 全件を取り直したいとき(★数の全更新・unstar反映)は: ./build.sh --full
set -euo pipefail
cd "$(dirname "$0")"

MODE="incremental"
SUMMARIZE=1   # 既定で要約(summarize.sh)も実行。--no-summary で抑制
for arg in "$@"; do
  case "$arg" in
    --full) MODE="full" ;;
    --no-summary) SUMMARIZE=0 ;;
  esac
done
# 手元に stars.json が無ければ強制フル
[ -f stars.json ] || MODE="full"

EXTRACT='.[] | {name: .repo.full_name, lang: (.repo.language // ""), desc: ((.repo.description // "") | gsub("[\r\n\t]"; " ")), stars: .repo.stargazers_count, url: .repo.html_url, starred_at: .starred_at}'
HDR="Accept: application/vnd.github.star+json"  # starred_at を得る

if [ "$MODE" = "full" ]; then
  echo "▶ [full] star全件を取得中..." >&2
  gh api user/starred --paginate -H "$HDR" -q "$EXTRACT" | jq -s '.' > fetched.json
else
  echo "▶ [incremental] 直近100件を取得中..." >&2
  # デフォルトで star日付の新しい順。最新ページ(100件)のみ。
  gh api "user/starred?per_page=100" -H "$HDR" -q "$EXTRACT" | jq -s '.' > fetched.json

  FETCHED=$(jq 'length' fetched.json)
  # 取得分のうち既知(手元stars.jsonに存在)の件数。0なら100件超の新規がある可能性 → フルを促す
  KNOWN=$(jq -n --slurpfile f fetched.json --slurpfile s stars.json \
    '([$s[0].categories[].repos[].name] | INDEX(.)) as $known
     | [$f[0][] | select($known[.name])] | length')
  if [ "$FETCHED" -ge 100 ] && [ "$KNOWN" -eq 0 ]; then
    echo "⚠ 直近100件が全て新規でした。100件以上starした可能性 → ./build.sh --full を推奨" >&2
  fi
fi

UPDATED=$(date '+%Y-%m-%d %H:%M')

# 既存(増分時のみ)とマージ → カテゴリ付与 → group化して stars.json を生成
if [ "$MODE" = "incremental" ]; then
  EXISTING="stars.json"
else
  echo '{"categories":[]}' > .empty.json
  EXISTING=".empty.json"
fi

jq -n \
  --arg updated "$UPDATED" \
  --slurpfile fetched fetched.json \
  --slurpfile existing "$EXISTING" \
  --slurpfile cats categories.json \
  --slurpfile meta category-meta.json '
  ($cats[0]) as $c
  | ($meta[0]) as $m
  # 既存の全repo(カテゴリ情報は捨てて素のフィールドだけ) を name->entry に
  | ([$existing[0].categories[]?.repos[]? | {name,lang,desc,stars,url,starred_at}] | INDEX(.name)) as $base
  # 取得分で上書き/追加（fetched優先 = 最新の★数/説明に更新）
  | (reduce $fetched[0][] as $r ($base; .[$r.name] = $r) | [.[]]) as $all
  | ($all | map(. + {category: ($c[.name] // "uncategorized")})) as $r
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
                repos: (sort_by(.starred_at) | reverse)
              }
          )
        | sort_by(.order)
      )
    }
  ' > stars.json.tmp && mv stars.json.tmp stars.json

rm -f .empty.json
TOTAL=$(jq '.total' stars.json)

# 未分類の検知
UNCAT=$(jq -r '.categories[] | select(.key=="uncategorized") | .repos[].name' stars.json 2>/dev/null || true)
if [ -n "$UNCAT" ]; then
  echo "⚠ 未分類のリポジトリがあります（categories.json に追記してください）:" >&2
  echo "$UNCAT" | sed 's/^/   - /' >&2
fi

echo "✅ stars.json を生成しました（${MODE} / 全${TOTAL}件）" >&2

# 各repoの日本語1行要約を生成・反映(キャッシュ済みは再生成しない)
if [ "$SUMMARIZE" -eq 1 ]; then
  if command -v claude >/dev/null 2>&1; then
    ./summarize.sh
  else
    echo "⚠ claude CLI が無いため要約をスキップ（--no-summary で明示的に抑制可）" >&2
  fi
fi
