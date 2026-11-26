#!/usr/bin/env node
// Node / web adapter. Fails when a built client bundle contains the private
// backend host or a public-environment marker. Run it after the production
// build. The goal: browsers talk only to the page's own origin (or to hosts
// you list in your public-surface allowlist), never to a private backend.
//
// Env:
//   BACKEND_URL_ENV   name of the variable that holds the private API URL
//                     (default API_BASE_URL); its value must be set.
//   CLIENT_BUNDLE_DIR directory with the built client files (default .next/static)
//   FORBIDDEN_MARKERS comma list of extra strings that must not appear
//                     (default NEXT_PUBLIC_; set to "" to disable)
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

const envName = process.env.BACKEND_URL_ENV || "API_BASE_URL";
const raw = process.env[envName];
if (!raw) {
  console.error(`${envName} must be set so the scan knows which host to reject.`);
  process.exit(1);
}

let parsed;
try {
  parsed = new URL(raw);
} catch {
  console.error(`${envName} must be an absolute http(s) URL.`);
  process.exit(1);
}

const root = path.resolve(process.env.CLIENT_BUNDLE_DIR || ".next/static");
const markers = (process.env.FORBIDDEN_MARKERS ?? "NEXT_PUBLIC_").split(",").map((s) => s.trim()).filter(Boolean);
const needles = needlesFor(raw, parsed, markers);
const hits = await scan(root, needles);
if (hits.length > 0) {
  console.error("Client bundle contains a backend host or a forbidden marker:");
  for (const hit of hits) console.error(hit);
  process.exit(1);
}
console.log(`Client bundle does not contain ${envName}${markers.length ? ` or ${markers.join(", ")}` : ""}.`);

/** Strings that must not appear in client files. */
function needlesFor(value, url, extra) {
  const found = new Set([value, url.host, ...extra]);
  const isIp = /^\d{1,3}(?:\.\d{1,3}){3}$/.test(url.hostname);
  if (!isIp && url.hostname !== "localhost") found.add(url.hostname);
  return [...found];
}

/** Files under `directory` that contain one of the terms. */
async function scan(directory, terms) {
  let entries;
  try {
    entries = await walk(directory);
  } catch {
    console.error(`Client bundle is missing at ${directory}. Run the production build first.`);
    process.exit(1);
  }
  const found = [];
  for (const file of entries) {
    const text = await readFile(file, "utf8");
    if (terms.some((term) => text.includes(term))) found.push(path.relative(process.cwd(), file));
  }
  return found;
}

/** Text artifacts under a directory, recursively. */
async function walk(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...(await walk(full)));
    else if (/\.(?:js|css|json|map|html|txt)$/.test(entry.name)) files.push(full);
  }
  return files;
}
