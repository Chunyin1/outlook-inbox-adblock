"use strict";
const fs = require("fs"),
  path = require("path");
const { targets, connect } = require("./connection.cjs");
const stateDir = __dirname;
const lock = path.join(stateDir, "helper.pid");
try {
  const pid = Number(fs.readFileSync(lock, "utf8"));
  if (pid > 0) {
    try {
      process.kill(pid, 0);
      process.exit(0);
    } catch {}
  }
} catch {}
fs.writeFileSync(lock, String(process.pid));
const source = fs.readFileSync(path.join(stateDir, "filter.js"), "utf8");
const sessions = new Map();
let stopping = false,
  lastStatus = "";
function status(value) {
  const text = JSON.stringify(value);
  if (text === lastStatus) return;
  lastStatus = text;
  const file = path.join(stateDir, "status.json");
  fs.writeFileSync(
    file + ".tmp",
    JSON.stringify({ ...value, checkedAt: new Date().toISOString() }, null, 2),
  );
  fs.renameSync(file + ".tmp", file);
}
let wakePending = false,
  wake,
  fastUntil = Date.now() + 5000;
const sleep = (ms) =>
  new Promise((resolve) => {
    if (wakePending) {
      wakePending = false;
      resolve();
      return;
    }
    const timer = setTimeout(() => {
      wake = null;
      resolve();
    }, ms);
    wake = () => {
      clearTimeout(timer);
      wake = null;
      wakePending = false;
      resolve();
    };
  });
// Outlook writes this file as its WebView starts, so attach without a polling delay.
let watcher;
try {
  watcher = fs.watch(
    path.join(process.env.LOCALAPPDATA, "Microsoft/Olk/EBWebView"),
    (_event, file) => {
      if (String(file) === "DevToolsActivePort") {
        fastUntil = Date.now() + 5000;
        wakePending = true;
        wake?.();
      }
    },
  );
  watcher.on("error", () => {});
} catch {}
async function stop() {
  stopping = true;
  watcher?.close();
  wake?.();
  for (const c of sessions.values()) c.close();
  try {
    if (fs.readFileSync(lock, "utf8") === String(process.pid))
      fs.unlinkSync(lock);
  } catch {}
}
process.on("SIGINT", () => stop());
process.on("SIGTERM", () => stop());
(async () => {
  while (!stopping) {
    try {
      const pages = await targets();
      const ids = new Set(pages.map((t) => t.id));
      for (const [id, c] of sessions)
        if (!ids.has(id)) {
          c.close();
          sessions.delete(id);
        }
      const results = [];
      for (const t of pages) {
        try {
          let c = sessions.get(t.id);
          if (!c) {
            c = await connect(t);
            sessions.set(t.id, c);
            await c.send("Page.addScriptToEvaluateOnNewDocument", { source });
          }
          const result = await c.send("Runtime.evaluate", {
            expression: source,
            returnByValue: true,
          });
          if (result.exceptionDetails) throw Error("Filter evaluation failed");
          if (result.result.value) results.push(result.result.value);
        } catch {
          sessions.get(t.id)?.close();
          sessions.delete(t.id);
        }
      }
      status({
        state: results.length ? "running" : "waiting-for-mail",
        pages: results,
      });
    } catch {
      for (const c of sessions.values()) c.close();
      sessions.clear();
      status({ state: "waiting-for-outlook" });
    }
    await sleep(sessions.size ? 2000 : Date.now() < fastUntil ? 150 : 1000);
  }
})().catch(() => {
  status({ state: "error" });
  stop();
  process.exitCode = 1;
});
