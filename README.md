# ⭐ github-stars

GitHubでstarしたリポジトリをカテゴリ別に閲覧できるサイト。

👉 **公開URL: https://rasukarusan.github.io/github-stars/**

## 構成

| ファイル | 役割 |
|---|---|
| `categories.json` | **分類マッピング本体**（`owner/repo` → カテゴリkey）。手動・スキルで育てる |
| `category-meta.json` | カテゴリの表示名・絵文字・並び順 |
| `build.sh` | `gh api`で最新starを取得し、分類を当てて `stars.json` を生成 |
| `stars.json` | ビューが読む生成物（コミット対象） |
| `index.html` | 閲覧UI（カテゴリchip・検索・言語フィルタ） |

## 更新方法

```bash
./build.sh           # 最新starを取得 → stars.json 再生成（未分類があれば警告表示）
git add -A && git commit -m "update stars" && git push
```

新しくstarしたリポジトリは `build.sh` 実行時に「未分類」として検知される。
Claude Codeで `/stars-sync` を叩くと、取得→未分類の自動分類→`categories.json`追記→生成→pushまでやる。

## カテゴリを直す

`categories.json` の該当行のカテゴリkeyを書き換えて `./build.sh` するだけ。
カテゴリ自体を増やす場合は `category-meta.json` にも定義を追加する。
