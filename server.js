// 依存ゼロの静的配信サーバー（npm start で起動）
const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = process.env.PORT || 8765;
const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

http
  .createServer((req, res) => {
    let p = decodeURIComponent(req.url.split("?")[0]);
    if (p === "/") p = "/index.html";
    const fp = path.join(__dirname, path.normalize(p));
    if (!fp.startsWith(__dirname)) {
      res.writeHead(403);
      res.end("forbidden");
      return;
    }
    fs.readFile(fp, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end("not found");
        return;
      }
      res.writeHead(200, {
        "Content-Type": TYPES[path.extname(fp)] || "application/octet-stream",
        "Cache-Control": "no-store",
      });
      res.end(data);
    });
  })
  .listen(PORT, () => {
    process.stdout.write(`\n  ⭐ github-stars → http://localhost:${PORT}/\n\n`);
  });
