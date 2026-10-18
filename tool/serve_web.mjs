// Servidor estático mínimo para probar el build web (PWA) en local:
//   flutter build web --release
//   node tool/serve_web.mjs [puerto]
// localhost cuenta como contexto seguro, así que el service worker y la
// instalación como app funcionan sin HTTPS.
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, normalize, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL("../build/web", import.meta.url)));
const port = Number(process.argv[2] ?? 8080);

const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".wasm": "application/wasm",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".otf": "font/otf",
  ".ttf": "font/ttf",
  ".frag": "application/octet-stream",
  ".bin": "application/octet-stream",
};

createServer(async (req, res) => {
  const pathname = decodeURIComponent(new URL(req.url, "http://x").pathname);
  let file = normalize(join(root, pathname));
  if (!file.startsWith(root)) {
    res.writeHead(403).end();
    return;
  }
  try {
    if ((await stat(file)).isDirectory()) file = join(file, "index.html");
    const body = await readFile(file);
    res.writeHead(200, {
      "Content-Type": types[extname(file)] ?? "application/octet-stream",
      "Cache-Control": "no-cache",
    });
    res.end(body);
  } catch {
    res.writeHead(404).end("Not found");
  }
}).listen(port, () => {
  console.log(`KikiDraw web en http://localhost:${port}`);
});
