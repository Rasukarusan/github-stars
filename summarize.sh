#!/usr/bin/env bash
# 各リポジトリの README を取得し、claude CLI で「日本語1行要約」を生成して
# summaries.json にキャッシュ。最後に stars.json の各repoへ summary を反映する。
#
# キャッシュ優先: summaries.json に既にある repo は再生成しない(API/LLM呼び出しゼロ)。
#   → 通常は新しくstarした repo だけが要約され、増分で育つ。
# 全件作り直し: ./summarize.sh --force
#
# 環境変数:
#   SUMMARY_README_CHARS  READMEから読む最大文字数 (既定 4000)
#   SUMMARY_LIMIT         1回の最大生成件数。初回バックフィルを分割したいとき (既定 0=無制限)
#   CLAUDE_MODEL          claude -p に渡すモデル (任意)
set -euo pipefail
cd "$(dirname "$0")"

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

CACHE="summaries.json"
[ -f "$CACHE" ] || echo '{}' > "$CACHE"
[ -f stars.json ] || { echo "✗ stars.json がありません。先に ./build.sh を実行してください。" >&2; exit 1; }

README_CHARS="${SUMMARY_README_CHARS:-4000}"
LIMIT="${SUMMARY_LIMIT:-0}"
MODEL_ARG=()
[ -n "${CLAUDE_MODEL:-}" ] && MODEL_ARG=(--model "$CLAUDE_MODEL")

# 要約対象を 1回の jq で抽出。通常はキャッシュ未登録のものだけ / --force は全件。
# 形式: name<TAB>desc<TAB>lang
WORK=$(mktemp)
trap 'rm -f "$WORK"' EXIT
if [ "$FORCE" -eq 1 ]; then
  jq -r '.categories[].repos[] | [.name, .desc, .lang] | @tsv' stars.json > "$WORK"
else
  jq -r --slurpfile sum "$CACHE" '
    ($sum[0]) as $s
    | .categories[].repos[] | select($s[.name] == null)
    | [.name, .desc, .lang] | @tsv' stars.json > "$WORK"
fi

TODO=$(wc -l < "$WORK" | tr -d ' ')
echo "▶ 要約対象: ${TODO}件$([ "$FORCE" -eq 1 ] && echo ' (--force 全件)')" >&2
[ "$TODO" -eq 0 ] && { echo "  新規なし。"; }

count=0
while IFS=$'\t' read -r name desc lang; do
  [ -z "$name" ] && continue
  if [ "$LIMIT" -gt 0 ] && [ "$count" -ge "$LIMIT" ]; then
    echo "… LIMIT(${LIMIT})到達。残りは次回実行で。" >&2
    break
  fi

  # README を raw で取得(無い/404はdescだけで要約)
  readme=$(gh api "repos/${name}/readme" -H "Accept: application/vnd.github.raw" 2>/dev/null | head -c "$README_CHARS" || true)

  prompt="次のGitHubリポジトリについて、日本語で簡潔な1行要約を作ってください。
制約: 40〜70字程度 / 何ができる・何のためのものかが一目で分かる / 句点・引用符・前置きや箇条書きは不要 / 要約本文のみを1行で出力。

リポジトリ名: ${name}
説明: ${desc:-（なし）}
主要言語: ${lang:-（不明）}
README抜粋:
${readme:-（取得できず）}"

  summary=$(printf '%s' "$prompt" | claude -p "${MODEL_ARG[@]}" 2>/dev/null | tr -d '\r' | sed '/^$/d' | head -1 || true)
  if [ -z "$summary" ]; then
    echo "⚠ 要約失敗(スキップ・次回再試行): ${name}" >&2
    continue
  fi

  # 1件ごとにキャッシュへ保存 → 途中で中断しても再開できる
  jq --arg n "$name" --arg s "$summary" --arg d "$(date '+%Y-%m-%d')" \
    '.[$n] = {summary:$s, generated_at:$d}' "$CACHE" > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
  count=$((count + 1))
  echo "✅ (${count}/${TODO}) ${name}: ${summary}" >&2
done < "$WORK"

# summaries.json を stars.json の各repoへ反映(キャッシュにある分だけ summary 付与)
jq --slurpfile sum "$CACHE" '
  ($sum[0]) as $s
  | .categories |= map(.repos |= map(. + {summary: ($s[.name].summary // "")}))
' stars.json > stars.json.tmp && mv stars.json.tmp stars.json

echo "✅ 要約を stars.json に反映しました (新規 ${count}件 / キャッシュ計 $(jq 'length' "$CACHE")件)" >&2
