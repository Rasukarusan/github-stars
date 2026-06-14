# ⭐ github-stars

GitHubでstarしたリポジトリをカテゴリ別に閲覧できるサイト。

👉 **公開URL: https://rasukarusan.github.io/github-stars/**

## 構成

| ファイル | 役割 |
|---|---|
| `categories.json` | **分類マッピング本体**（`owner/repo` → カテゴリkey）。手動・スキルで育てる |
| `category-meta.json` | カテゴリの表示名・絵文字・並び順 |
| `build.sh` | star取得→分類適用→`stars.json`生成→要約反映。既定は増分(直近100件)、全件は `--full`、要約抑制は `--no-summary` |
| `summarize.sh` | 各repoのREADMEを取得し `claude` CLI で日本語1行要約を生成、`summaries.json` にキャッシュ。全件は `--force` |
| `summaries.json` | LLM要約のキャッシュ（`owner/repo` → 要約）。コミット対象 |
| `stars.json` | ビューが読む生成物（`summary` 付き・コミット対象） |
| `index.html` | 閲覧UI（カテゴリchip・検索・ソート・star日付の期間フィルタ・一覧/カテゴリ別切替・ライト/ダークテーマ） |
| `server.js` | ローカル閲覧用の依存ゼロ静的サーバー |
| `package.json` | npmスクリプト（start / build / sync / summarize / resummarize） |

## ローカルで見る

`index.html` は `stars.json` を fetch するので `file://` では動かない。サーバー経由で開く（依存インストール不要）:

```bash
npm start            # http://localhost:8765/ で起動（PORT=xxxx で変更可）
```

## 更新方法

```bash
npm run build        # = ./build.sh : 増分で最新starを取得 → stars.json 再生成 → 新規repoの要約生成
npm run sync         # = ./build.sh --full : 全件取り直し（★数の全更新・unstar反映）
git add -A && git commit -m "update stars" && git push
```

## LLM要約

各repoカードには `claude` CLI で生成した日本語1行要約を表示する。`build.sh` 実行時、
`summaries.json` に未登録のrepoだけが自動で要約される（増分なので新規starした分のみ）。

```bash
npm run summarize    # = ./summarize.sh : 未要約のrepoだけ要約（READMEを取得 → claude -p）
npm run resummarize  # = ./summarize.sh --force : 全repoを作り直し
./build.sh --no-summary   # 要約をスキップしてstars.jsonだけ更新
```

- 要約は **READMEの先頭** と GitHub の説明文をもとに生成（`SUMMARY_README_CHARS` で文字数調整）。
- 初回は全repo分のバックフィルになるので時間がかかる。`SUMMARY_LIMIT=50 ./summarize.sh` のように
  分割実行でき、1件ごとにキャッシュ保存するので途中で中断しても次回続きから再開する。
- `gh`(認証済み) と `claude` CLI が必要。`claude` が無い場合 `build.sh` は要約をスキップする。

新しくstarしたリポジトリは `build.sh` 実行時に「未分類」として検知される。
Claude Codeで `/stars-sync` を叩くと、取得→未分類の自動分類→`categories.json`追記→生成→pushまでやる。

## カテゴリを直す

`categories.json` の該当行のカテゴリkeyを書き換えて `./build.sh` するだけ。
カテゴリ自体を増やす場合は `category-meta.json` にも定義を追加する。
