#!/usr/bin/env node
// Feature-flag expiry gate. Usage: node feature-flag-expiry.mjs <repo dir>
// Every flag needs id, owner, purpose and expiresOn (YYYY-MM-DD). A flag past
// its expiry fails the check: remove it, or extend it with a recorded reason.
// Registry paths, first existing wins per path (all existing ones are checked):
//   contracts/feature-flags.json, .github/policy/feature-flags.json, feature-flags.json
// A repository with no registry passes (it has no flags yet).
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const repo = process.argv[2] ?? ".";
const candidates = ["contracts/feature-flags.json", ".github/policy/feature-flags.json", "feature-flags.json"];

const today = new Date().toISOString().slice(0, 10);
const findings = [];

const validate = (file, data) => {
  if (!data || typeof data !== "object") {
    findings.push({ file, line: 1, message: "registry must be a JSON object" });
    return;
  }
  if (!Array.isArray(data.flags)) {
    findings.push({ file, line: 1, message: "registry.flags must be an array" });
    return;
  }
  const seen = new Set();
  data.flags.forEach((flag, index) => {
    const line = index + 1;
    if (!flag || typeof flag !== "object") {
      findings.push({ file, line, message: `flags[${index}] must be an object` });
      return;
    }
    for (const field of ["id", "owner", "purpose", "expiresOn"]) {
      if (typeof flag[field] !== "string" || !flag[field].trim()) {
        findings.push({ file, line, message: `flags[${index}].${field} is required` });
      }
    }
    if (typeof flag.id === "string") {
      if (seen.has(flag.id)) findings.push({ file, line, message: `duplicate flag id ${flag.id}` });
      seen.add(flag.id);
    }
    if (typeof flag.expiresOn === "string" && /^\d{4}-\d{2}-\d{2}$/.test(flag.expiresOn)) {
      if (flag.expiresOn < today) {
        findings.push({ file, line, message: `flag ${flag.id} expired on ${flag.expiresOn}: remove it or extend it with a recorded reason` });
      }
    } else if (typeof flag.expiresOn === "string") {
      findings.push({ file, line, message: `flags[${index}].expiresOn must be YYYY-MM-DD` });
    }
  });
};

let checked = 0;
for (const relative of candidates) {
  const path = join(repo, relative);
  if (!existsSync(path)) continue;
  checked += 1;
  try {
    validate(relative, JSON.parse(readFileSync(path, "utf8")));
  } catch (error) {
    findings.push({ file: relative, line: 1, message: `invalid JSON: ${error.message}` });
  }
}

for (const finding of findings) {
  console.log(`::error file=${finding.file},line=${finding.line}::[flag-expiry] ${finding.message}`);
}
if (findings.length > 0) {
  console.log(`feature-flag-expiry: ${findings.length} finding(s)`);
  process.exit(1);
}
console.log(`feature-flag-expiry: ok (${checked} registry file(s), today ${today})`);
