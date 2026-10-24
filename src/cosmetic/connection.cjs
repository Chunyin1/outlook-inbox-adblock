const fs = require("fs"),
  path = require("path");
const originOK = (u) => {
  try {
    return /^https:\/\/outlook\.(office\.com|live\.com|office365\.com|cloud\.microsoft)$/.test(
      new URL(u).origin,
    );
  } catch {
    return false;
  }
};
async function targets() {
  const port = Number(
    fs
      .readFileSync(
        path.join(
          process.env.LOCALAPPDATA,
          "Microsoft/Olk/EBWebView/DevToolsActivePort",
        ),
        "utf8",
      )
      .split("\n")[0],
  );
  if (!Number.isInteger(port) || port < 1024 || port > 65535)
    throw new Error("Invalid port");
  return (
    await (
      await fetch("http://127.0.0.1:" + port + "/json/list", {
        signal: AbortSignal.timeout(2000),
        redirect: "error",
      })
    ).json()
  )
    .filter(
      (t) => t.type === "page" && (t.url === "about:blank" || originOK(t.url)),
    )
    .map((t) => ({ ...t, port }));
}
async function connect(t) {
  const u = new URL(t.webSocketDebuggerUrl);
  if (
    u.protocol !== "ws:" ||
    u.username ||
    u.password ||
    !["127.0.0.1", "localhost", "[::1]"].includes(u.hostname) ||
    Number(u.port) !== t.port
  )
    throw new Error("Not loopback");
  const ws = new WebSocket(u),
    pending = new Map();
  let seq = 0;
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      ws.close();
      reject(Error("Connection timed out"));
    }, 5000);
    ws.addEventListener(
      "open",
      () => {
        clearTimeout(timer);
        resolve();
      },
      { once: true },
    );
    ws.addEventListener(
      "error",
      () => {
        clearTimeout(timer);
        reject(Error("Connection failed"));
      },
      { once: true },
    );
  });
  ws.addEventListener("message", (e) => {
    const m = JSON.parse(e.data);
    const q = pending.get(m.id);
    if (q) {
      pending.delete(m.id);
      clearTimeout(q.timer);
      m.error ? q.reject(Error(m.error.message)) : q.resolve(m.result);
    }
  });
  ws.addEventListener("close", () => {
    for (const q of pending.values()) {
      clearTimeout(q.timer);
      q.reject(Error("Closed"));
    }
    pending.clear();
  });
  return {
    send(method, params = {}) {
      return new Promise((resolve, reject) => {
        const id = ++seq,
          timer = setTimeout(() => {
            pending.delete(id);
            reject(Error("Timeout"));
          }, 8000);
        pending.set(id, { resolve, reject, timer });
        ws.send(JSON.stringify({ id, method, params }));
      });
    },
    close() {
      ws.close();
    },
  };
}
module.exports = { targets, connect };
