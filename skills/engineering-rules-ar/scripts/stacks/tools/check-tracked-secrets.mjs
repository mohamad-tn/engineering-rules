#!/usr/bin/env node
// React Native / mobile adapter (works for any repository). Fails when a
// signing keystore, credential file or private key is tracked in git, or when
// source files contain a literal signing password, a private-key header or a
// cleartext http:// URL. Release signing material lives in a secret store,
// never in git.
//
// Env: SOURCE_ROOTS (comma list of directories scanned for content, default
//      "src/,app/,apps/,packages/,scripts/"), ALLOW_HTTP_HOSTS (comma list of
//      hosts allowed over http, default "localhost,127.0.0.1,10.0.2.2").
import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";

const root = process.cwd();
const files = execSync("git ls-files --cached --others --exclude-standard", { cwd: root, encoding: "utf8" })
  .split("\n")
  .filter(Boolean);

const blockedName =
  /\.(jks|keystore|p12|pfx|p8|mobileprovision)$|(^|\/)(credentials\.json|google-services\.json|GoogleService-Info\.plist)$/;
const blocked = files.filter((file) => blockedName.test(file));
if (blocked.length > 0) {
  process.stderr.write(`tracked secret files:\n${blocked.join("\n")}\n`);
  process.exitCode = 1;
}

const sourceRoots = (process.env.SOURCE_ROOTS ?? "src/,app/,apps/,packages/,scripts/").split(",").map((s) => s.trim());
const allowedHosts = (process.env.ALLOW_HTTP_HOSTS ?? "localhost,127.0.0.1,10.0.2.2").split(",").map((s) => s.trim());
// Built from parts so this file does not match its own patterns.
const passwordPattern = new RegExp(`\\b(?:store|key)[_-]?${["pass", "word"].join("")}["']?\\s*[:=]\\s*["'][^"'\\s$]{4,}["']`, "i");
const keyHeader = new RegExp(`BEGIN (?:RSA |OPENSSH |EC )?PRIVATE ${"KEY"}`);
const httpUrl = /http:\/\/([A-Za-z0-9.-]+)/g;

for (const file of files) {
  if (!sourceRoots.some((prefix) => file.startsWith(prefix)) || /\.(png|jpe?g|gif|webp|ico|ttf|otf|woff2?)$/.test(file)) continue;
  const body = readFileSync(path.join(root, file), "utf8");
  const insecure = [...body.matchAll(httpUrl)].some((m) => !allowedHosts.includes(m[1]));
  if (passwordPattern.test(body) || keyHeader.test(body) || insecure) {
    process.stderr.write(`forbidden content in ${file}\n`);
    process.exitCode = 1;
  }
}

if (process.exitCode) process.exit(process.exitCode);
process.stdout.write("No keystores, private keys, literal signing passwords or cleartext URLs in source.\n");
