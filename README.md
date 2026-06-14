# ⭐ github-stars

GitHubでstarしたリポジトリをカテゴリ別に閲覧できるサイト。

👉 **公開URL: https://rasukarusan.github.io/github-stars/**

## 構成

| ファイル | 役割 |
|---|---|
| `categories.json` | **分類マッピング本体**（`owner/repo` → カテゴリkey）。手動・スキルで育てる |
| `category-meta.json` | カテゴリの表示名・絵文字・並び順 |
| `build.sh` | star取得→分類適用→`stars.json`生成。既定は増分(直近100件)、全件は `--full` |
| `stars.json` | ビューが読む生成物（コミット対象） |
| `index.html` | 閲覧UI（カテゴリchip・検索・ソート・star日付の期間フィルタ・一覧/カテゴリ別切替・ライト/ダークテーマ） |
| `server.js` | ローカル閲覧用の依存ゼロ静的サーバー |
| `package.json` | npmスクリプト（start / build / sync） |

## ローカルで見る

`index.html` は `stars.json` を fetch するので `file://` では動かない。サーバー経由で開く（依存インストール不要）:

```bash
npm start            # http://localhost:8765/ で起動（PORT=xxxx で変更可）
```

## 更新方法

```bash
npm run build        # = ./build.sh : 増分で最新starを取得 → stars.json 再生成
npm run sync         # = ./build.sh --full : 全件取り直し（★数の全更新・unstar反映）
git add -A && git commit -m "update stars" && git push
```

新しくstarしたリポジトリは `build.sh` 実行時に「未分類」として検知される。
Claude Codeで `/stars-sync` を叩くと、取得→未分類の自動分類→`categories.json`追記→生成→pushまでやる。

## カテゴリを直す

`categories.json` の該当行のカテゴリkeyを書き換えて `./build.sh` するだけ。
カテゴリ自体を増やす場合は `category-meta.json` にも定義を追加する。
