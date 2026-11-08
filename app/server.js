// Tiny demo app. Behaviour is controlled by environment variables so the
// same image can act as the stable version or a (good or bad) canary.
const http = require("http");
const os = require("os");

const VERSION = process.env.APP_VERSION || "v1";
const ERROR_RATE = parseFloat(process.env.ERROR_RATE || "0"); // 0.0 to 1.0
const DELAY_MS = parseInt(process.env.DELAY_MS || "0", 10);
const PORT = parseInt(process.env.PORT || "8080", 10);

const server = http.createServer((req, res) => {
  if (req.url === "/healthz") {
    res.writeHead(200, { "Content-Type": "text/plain" });
    return res.end("ok");
  }
  setTimeout(() => {
    const failed = Math.random() < ERROR_RATE;
    const body = JSON.stringify({
      version: VERSION,
      pod: os.hostname(),
      status: failed ? "error" : "ok",
    });
    res.writeHead(failed ? 500 : 200, {
      "Content-Type": "application/json",
      "X-App-Version": VERSION,
    });
    res.end(body);
  }, DELAY_MS);
});

server.listen(PORT, () => console.log(`app ${VERSION} listening on ${PORT}`));
