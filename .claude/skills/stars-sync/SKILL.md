---
name: stars-sync
description: GitHubのstar一覧を最新化し、新しくstarしたリポジトリのカテゴリ分類とLLM日本語要約を付与して github-stars サイト(stars.json)を更新・pushする。「starを同期」「スター分類更新」「star要約」などで起動。
---

# stars-sync

GitHubでstarしたリポジトリのカテゴリ別閲覧サイト（公開: https://rasukarusan.github.io/github-stars/）を最新化するスキル。**カテゴリ分類**と**日本語1行要約**の両方を付与する。要約はこのスキル（＝あなた自身）が生成するので `claude -p` などの外部LLM呼び出しは不要。

## 前提

- リポジトリ直下で作業する（`build.sh` のあるディレクトリ）。
- `categories.json` … 分類マッピング本体（`owner/repo` → カテゴリkey）
- `category-meta.json` … カテゴリ定義（label/emoji/order）
- `summaries.json` … 要約キャッシュ（`owner/repo` → `{summary, generated_at}`）。**要約の生成元はここ**
- `build.sh` … star取得→分類適用→`summaries.json`反映→`stars.json`生成。既定は増分(直近100件)、全件は `./build.sh --full`。LLMは呼ばない。

## 手順

1. `./build.sh` を実行する。出力の末尾に状況が出る:
   - `⚠ 未分類のリポジトリがあります` … 分類が必要（手順2）
   - `ℹ 未要約のリポジトリが N件 あります` … 要約が必要（手順3）
   - どちらも無ければ変更なし。手順5へ。

2. **分類**: 未分類の各 `owner/repo` について、`gh api repos/{owner}/{repo} -q '.description, (.language//""), (.topics|join(","))'` で説明・言語・topicsを確認し、`category-meta.json` の既存カテゴリkeyに振り分け、`categories.json` に `"owner/repo": "カテゴリkey"` を追記する。
   - 基本は説明文から自動判断。迷う場合のみユーザーに確認。
   - 合うカテゴリが無く同種が複数あるなら、新カテゴリを `category-meta.json` に追加してよい（label/emoji/order を付与）。

3. **要約**: 未要約のrepo一覧を取得する:
   ```bash
   jq -r '.categories[].repos[] | select((.summary // "") == "") | .name' stars.json
   ```
   各repoについて日本語1行要約を作り、`summaries.json` に追記する:
   - まず GitHub の説明文で方向性を掴む。情報が薄い/英語で内容が掴みにくいときは `gh api repos/{owner}/{repo}/readme -H "Accept: application/vnd.github.raw"` でREADME冒頭を読む。著名repoは自分の知識で書いてよい。
   - 要約は **40〜70字程度・日本語・「何ができる/何のためのものか」が一目で分かる・句点や前置きなし**。
   - `summaries.json` に次の形で追記（既存JSONを壊さない）:
     ```json
     "owner/repo": { "summary": "要約本文", "generated_at": "YYYY-MM-DD" }
     ```
   - **件数が多い場合（初回バックフィル等）はコンテキスト上限を避けるため 30〜50件ずつのバッチで進める。** `summaries.json` は1バッチごとに保存すれば途中再開できる。

4. `./build.sh` を再実行し、`⚠ 未分類` が消え、`ℹ 未要約` が0件（または残数が想定どおり）になったこと・`total`件数を確認する。

5. `git add -A && git commit -m "stars: 同期（新規N件を分類・M件を要約）" && git push` する。
   - 件数・追加カテゴリをコミットメッセージに反映する。

6. 完了を報告（取得総数 / 新規分類 / 新規要約 / 新カテゴリの有無）。

## メモ

- `fetched.json` は中間生成物で `.gitignore` 済み。コミット対象は `stars.json` / `summaries.json` / 各設定JSON。
- 要約・分類は `summaries.json` / `categories.json` がソース・オブ・トゥルース。`build.sh` は貼り込みと生成だけ。
- 既存の分類や要約を直したいときは、対応するJSONの値を書き換えて `./build.sh` するだけ。
- 大量バックフィルだけ手早く回したいときは `SUMMARY_LIMIT` 的な分割は無いので、手順3のバッチ処理で件数を区切る。
