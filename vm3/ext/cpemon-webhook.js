const url = require("url");
const http = require("http");
const https = require("https");
const crypto = require("crypto");

// 目标 Webhook 地址 & 秘钥，可以通过环境变量覆盖
const API_URL =
  process.env.CPEMON_WEBHOOK_URL || "http://api.local/acs/webhook";
const SECRET =
  process.env.CPEMON_WEBHOOK_SECRET || "cpemon-demo-secret";

function sendEvent(args, callback) {
  try {
    const payload = JSON.parse(args[0]);
    const body = JSON.stringify(payload);

    const parsed = url.parse(API_URL);
    const client = parsed.protocol === "https:" ? https : http;

    const options = {
      hostname: parsed.hostname,
      port:
        parsed.port ||
        (parsed.protocol === "https:" ? 443 : 80),
      path: parsed.path || "/acs/webhook",
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(body),
        "X-Cpemon-Signature": crypto
          .createHmac("sha256", SECRET)
          .update(body)
          .digest("hex"),
      },
    };

    console.log(
      "cpemon-webhook: POST",
      options.hostname + ":" + options.port,
      options.path
    );

    const req = client.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk.toString()));
      res.on("end", () => {
        console.log(
          "cpemon-webhook: response",
          res.statusCode,
          data.slice(0, 200)
        );
        // 不因为 HTTP 状态码失败而中断 Provision
        callback(null, { statusCode: res.statusCode });
      });
    });

    req.on("error", (err) => {
      console.error("cpemon-webhook: error", err);
      // 网络错误也只是打个 log，不让 Provision 报错
      callback(null, null);
    });

    req.write(body);
    req.end();
  } catch (err) {
    console.error("cpemon-webhook: exception", err);
    callback(null, null);
  }
}

exports.sendEvent = sendEvent;
