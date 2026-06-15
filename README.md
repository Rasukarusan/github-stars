# ⭐ github-stars

GitHubでstarしたリポジトリをカテゴリ別に閲覧できるサイト。

👉 **公開URL: https://rasukarusan.github.io/github-stars/**

## 構成

| ファイル | 役割 |
|---|---|
| `categories.json` | **分類マッピング本体**（`owner/repo` → カテゴリkey）。手動・スキルで育てる |
| `category-meta.json` | カテゴリの表示名・絵文字・並び順 |
| `build.sh` | star取得→分類適用→`summaries.json`反映→`stars.json`生成。既定は増分(直近100件)、全件は `--full` |
| `summaries.json` | LLM要約のキャッシュ（`owner/repo` → `{summary}`）。生成は `stars-sync` スキル、`build.sh` は貼り込むだけ。コミット対象 |
| `stars.json` | ビューが読む生成物（`summary` 付き・コミット対象） |
| `index.html` | 閲覧UI（カテゴリchip・検索・ソート・star日付の期間フィルタ・一覧/カテゴリ別切替・ライト/ダークテーマ） |
| `server.js` | ローカル閲覧用の依存ゼロ静的サーバー |
| `package.json` | npmスクリプト（start / build / sync） |
| `.claude/skills/stars-sync/` | star同期＋未分類の分類＋未要約の要約を行うClaude Codeスキル |

## ローカルで見る

`index.html` は `stars.json` を fetch するので `file://` では動かない。サーバー経由で開く（依存インストール不要）:

```bash
npm start            # http://localhost:8765/ で起動（PORT=xxxx で変更可）
```

## 更新方法

```bash
npm run build        # = ./build.sh : 増分で最新starを取得 → stars.json 再生成（要約はキャッシュを反映）
npm run sync         # = ./build.sh --full : 全件取り直し（★数の全更新・unstar反映）
git add -A && git commit -m "update stars" && git push
```

## LLM要約

各repoカードには日本語1行要約を表示する。要約は **Claude Code の `stars-sync` スキル** が
READMEや説明文をもとに生成して `summaries.json`（`owner/repo` → `{summary}`）にキャッシュし、
`build.sh` がそれを `stars.json` に貼り込む。`build.sh` 自体はLLMを呼ばない（高速・認証不要）。

- `build.sh` 実行後、`ℹ 未要約のリポジトリが N件` と出たら未要約。`stars-sync` スキルを
  叩くと、未分類の分類と未要約の要約をまとめて行い、`summaries.json` を追記して push まで実行する。
- 要約はキャッシュなので、新しくstarした分だけが増分で要約される。
- 初回は全repo分のバックフィルになるので、スキル側でバッチに分けて生成する。

新しくstarしたリポジトリは `build.sh` 実行時に「未分類」として検知される。
Claude Codeで `/stars-sync` を叩くと、取得→未分類の自動分類→`categories.json`追記→生成→pushまでやる。

## カテゴリを直す

`categories.json` の該当行のカテゴリkeyを書き換えて `./build.sh` するだけ。
カテゴリ自体を増やす場合は `category-meta.json` にも定義を追加する。
