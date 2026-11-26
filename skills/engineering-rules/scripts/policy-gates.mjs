#!/usr/bin/env node
// Policy gates. Usage: node policy-gates.mjs <repo dir>
//
// 1. prerelease: no alpha/beta/rc/preview/canary/nightly versions in direct
//    dependencies of package.json, *.csproj, *.props, *.targets and the
//    "Direct" entries of packages.lock.json, unless listed in
//    prerelease-allow.json with the decision record (ADR) that justifies it.
// 2. country-literals: no currency codes, region codes, time-zone ids, dial
//    prefixes or named places in product code. Seeds, tests, docs and tooling
//    configuration are outside the gate (see country-literals.json).
//
// Rules live in a policy directory, searched in this order:
//   $POLICY_DIR, <repo>/.github/policy, <this script's dir>/policy
// Run the feature-flag gate separately: feature-flag-expiry.mjs.
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repo = process.argv[2] ?? ".";
const scriptDir = dirname(fileURLToPath(import.meta.url));
const policyDirs = [process.env.POLICY_DIR, join(repo, ".github", "policy"), join(scriptDir, "policy")].filter(Boolean);

/** Reads a JSON policy file from the first policy directory that has it. */
const readPolicy = (name, fallback) => {
  const found = policyDirs.map((dir) => join(dir, name)).find((path) => existsSync(path));
  return found ? JSON.parse(readFileSync(found, "utf8")) : fallback;
};

const prereleaseAllow = readPolicy("prerelease-allow.json", []);
const literals = readPolicy("country-literals.json", null);
if (!literals) {
  console.error("policy-gates: country-literals.json not found in any policy directory");
  process.exit(1);
}

const PRERELEASE = /-(alpha|beta|rc|preview|pre|canary|nightly|next|dev|insiders|experimental)([.\d-]|$)/i;

const files = execFileSync("git", ["-C", repo, "ls-files", "-z"], { encoding: "utf8" })
  .split("\0")
  .filter(Boolean);

const findings = [];
const report = (gate, file, line, message) => findings.push({ gate, file, line, message });

/** True when the dependency is allowed by a decision-record entry. */
const isAllowed = (name, version) => prereleaseAllow.some((e) => e.name === name && e.version === version);

const checkVersion = (file, name, version) => {
  if (typeof version !== "string" || !PRERELEASE.test(version) || isAllowed(name, version)) return;
  report("prerelease", file, 1, `${name}@${version} is a prerelease (needs a decision record and an allowlist entry)`);
};

const inNodeModules = (file) => file.split("/").includes("node_modules");

for (const file of files) {
  if (inNodeModules(file)) continue;
  const base = file.split("/").pop();
  if (base === "package.json") {
    const manifest = JSON.parse(readFileSync(join(repo, file), "utf8"));
    for (const field of ["dependencies", "devDependencies", "peerDependencies", "optionalDependencies", "overrides"]) {
      for (const [name, version] of Object.entries(manifest[field] ?? {})) checkVersion(file, name, version);
    }
  } else if (base === "packages.lock.json") {
    const lock = JSON.parse(readFileSync(join(repo, file), "utf8"));
    for (const deps of Object.values(lock.dependencies ?? {})) {
      for (const [name, info] of Object.entries(deps)) {
        if (info.type === "Direct") checkVersion(file, name, info.resolved);
      }
    }
  } else if (/\.(csproj|props|targets)$/.test(base)) {
    const text = readFileSync(join(repo, file), "utf8");
    for (const match of text.matchAll(/<PackageReference\s+Include="([^"]+)"\s+Version="([^"]+)"/g)) {
      checkVersion(file, match[1], match[2]);
    }
  }
}

const codeExtensions = new Set(literals.codeExtensions);
const excluded = literals.excludedPathPatterns.map((pattern) => new RegExp(pattern));
const alternation = (items) => items.map((s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|");
const tokenRules = [];
if (literals.currencyCodes?.length) {
  tokenRules.push({ name: "currency code", regex: new RegExp(`["'\`](${alternation(literals.currencyCodes)})["'\`]`) });
}
if (literals.regionCodes?.length) {
  tokenRules.push({ name: "region code", regex: new RegExp(`["'\`](${alternation(literals.regionCodes)})["'\`]`) });
}
if (literals.timeZoneAreas?.length) {
  tokenRules.push({ name: "time-zone id", regex: new RegExp(`["'\`](${alternation(literals.timeZoneAreas)})/[A-Za-z_+-]+["'\`]`) });
}
tokenRules.push({ name: "dial prefix", regex: /["'`]\+\d{1,3}["'`]/ });
if (literals.placeNames?.length) {
  tokenRules.push({ name: "named place", regex: new RegExp(`\\b(${alternation(literals.placeNames)})\\b`, "i") });
}

for (const file of files) {
  const extension = file.includes(".") ? file.slice(file.lastIndexOf(".")) : "";
  if (!codeExtensions.has(extension) || excluded.some((pattern) => pattern.test(file))) continue;
  const lines = readFileSync(join(repo, file), "utf8").split("\n");
  lines.forEach((text, index) => {
    for (const rule of tokenRules) {
      const match = text.match(rule.regex);
      if (match) report("country-literals", file, index + 1, `${rule.name} literal ${match[0]} (configuration is data, not code)`);
    }
  });
}

for (const finding of findings) {
  console.log(`::error file=${finding.file},line=${finding.line}::[${finding.gate}] ${finding.message}`);
}
if (findings.length > 0) {
  console.log(`policy-gates: ${findings.length} finding(s)`);
  process.exit(1);
}
console.log(`policy-gates: ok (${files.length} tracked files checked)`);
