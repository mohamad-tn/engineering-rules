#!/usr/bin/env node
// docs-check, structural part. Usage: node docs-check.mjs <repo dir>
//
// Fails (exit 1, every failure listed at once) when:
//   0. a required doc is missing, or docs/docs-map.yml is malformed;
//   1. (pull requests) a changed file matches a `code` glob in the docs map and
//      none of its `docs` globs changed in the same pull request, unless the
//      pull request has the skip label (a reviewer must accept the reason);
//   2. (pull requests) CHANGELOG.md was not touched and the Conventional Commit
//      type of the pull-request title is not exempt (chore / ci / test).
// Markdown lint and the link check run from docs-check.sh.
//
// Pull-request inputs come from the environment: BASE_SHA, HEAD_SHA,
// PR_LABELS_JSON, PR_TITLE. Without BASE_SHA/HEAD_SHA only the whole-repo
// checks run (push, schedule, local run without a base).
//
// Optional env: DOCS_MAP_FILE (docs/docs-map.yml), DOCS_REQUIRED_FILE
// (.github/docs-check/required-docs.json; relative to the repository or an
// absolute path), DOCS_SKIP_LABEL (no-docs-needed),
// DOCS_DEPENDENCY_LABEL (dependencies), DOCS_NO_CHANGELOG_TYPES
// (chore,ci,test), DOCS_SYNCED_FILES (comma list of files copied from another
// repository; they are not mapped here), REPO_NAME (key in required-docs.json).
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { basename, isAbsolute, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const env = process.env;
const list = (value, fallback) =>
  (value ?? fallback).split(",").map((s) => s.trim()).filter(Boolean);

const MAP_FILE = env.DOCS_MAP_FILE || "docs/docs-map.yml";
const REQUIRED_FILE = env.DOCS_REQUIRED_FILE || ".github/docs-check/required-docs.json";
const SKIP_LABEL = env.DOCS_SKIP_LABEL || "no-docs-needed";
const DEPENDENCY_LABEL = env.DOCS_DEPENDENCY_LABEL || "dependencies";
const NO_CHANGELOG_TYPES = new Set(list(env.DOCS_NO_CHANGELOG_TYPES, "chore,ci,test"));
const SYNCED_FILES = new Set(list(env.DOCS_SYNCED_FILES, ""));
// "on" (default): changed code needs matching docs. "required-only": only the
// required-docs list and the changelog rule apply (profile lite).
const MAP_RULE_ENABLED = (env.DOCS_MAP_MODE || "on") !== "required-only";

// Files a dependency-bot update may touch while skipping the map rule.
const DEPENDENCY_FILE =
  /(?:^|\/)(?:package(?:-lock)?\.json|packages\.lock\.json|Directory\.Packages\.props|global\.json|[^/]+\.csproj|\.nvmrc|\.node-version|Dockerfile[^/]*|compose[^/]*\.ya?ml|\.pre-commit-config\.yaml|renovate\.json|[^/]+\.lock)$|^\.github\/workflows\/[^/]+\.ya?ml$/;

/**
 * Glob to RegExp: `**` spans directories, `*` and `?` stay inside one path
 * segment, `{a,b}` is alternation. `[` is literal (framework routes use it).
 * @param {string} glob
 * @returns {RegExp}
 */
export function globToRegExp(glob) {
  let re = "";
  let depth = 0;
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*" && glob[i + 1] === "*") {
      const slash = glob[i + 2] === "/";
      re += slash ? "(?:.*/)?" : ".*";
      i += slash ? 2 : 1;
    } else if (c === "*") re += "[^/]*";
    else if (c === "?") re += "[^/]";
    else if (c === "{") {
      depth++;
      re += "(?:";
    } else if (c === "}" && depth > 0) {
      depth--;
      re += ")";
    } else if (c === "," && depth > 0) re += "|";
    else re += c.replace(/[.+^$()|[\]\\{},]/g, "\\$&");
  }
  return new RegExp(`^${re}$`);
}

/** Removes matching quotes around a scalar. */
const unquote = (text) => {
  const t = text.trim();
  return t.length >= 2 && (t[0] === '"' || t[0] === "'") && t.at(-1) === t[0] ? t.slice(1, -1) : t;
};

/** Splits a flow list body on commas that are outside quotes and braces. */
function splitFlowList(body) {
  const items = [];
  let current = "";
  let quote = "";
  let braces = 0;
  for (const c of body) {
    if (quote) {
      if (c === quote) quote = "";
      current += c;
    } else if (c === '"' || c === "'") {
      quote = c;
      current += c;
    } else if (c === "{") {
      braces++;
      current += c;
    } else if (c === "}") {
      braces--;
      current += c;
    } else if (c === "," && braces === 0) {
      items.push(current);
      current = "";
    } else current += c;
  }
  if (current.trim()) items.push(current);
  return items.map(unquote).filter(Boolean);
}

/**
 * Parses the docs map. Supported subset of YAML (kept strict on purpose so
 * the gate needs no dependency):
 *   - code: "<glob>"
 *     docs: ["<glob>", "<glob>"]
 * @param {string} text
 * @returns {{entries: {code: string, docs: string[]}[], errors: string[]}}
 */
export function parseDocsMap(text) {
  const entries = [];
  const errors = [];
  let current = null;
  text.split(/\r?\n/).forEach((raw, index) => {
    const line = raw.trimEnd();
    if (!line.trim() || line.trim().startsWith("#")) return;
    const code = /^-\s*code:\s*(.+)$/.exec(line);
    const docs = /^\s+docs:\s*\[(.*)\]$/.exec(line);
    if (code) {
      current = { code: unquote(code[1]), docs: [] };
      entries.push(current);
    } else if (docs && current) {
      current.docs = splitFlowList(docs[1]);
    } else {
      errors.push(
        `${MAP_FILE} line ${index + 1}: unsupported syntax. Use \`- code: "<glob>"\` followed by \`  docs: ["<glob>", ...]\``,
      );
    }
  });
  entries.forEach((entry, i) => {
    if (!entry.code || entry.docs.length === 0) {
      errors.push(`${MAP_FILE} entry ${i + 1}: needs a "code" glob and a non-empty "docs" list`);
    }
  });
  return { entries, errors };
}

/**
 * Commit type of a Conventional Commit title, or undefined.
 * @param {string} title
 * @returns {string | undefined}
 */
export function conventionalType(title) {
  return /^([a-z]+)(?:\([^)]*\))?!?:/.exec(title ?? "")?.[1];
}

function run(repoDir) {
  // Config paths are relative to the repository, or absolute (shared setups).
  const inRepo = (path) => (isAbsolute(path) ? path : join(repoDir, path));
  const failures = [];
  const fail = (message) => failures.push(message);
  const repoName = env.REPO_NAME || basename(repoDir);

  // 0. Required docs.
  if (existsSync(inRepo(REQUIRED_FILE))) {
    const required = JSON.parse(readFileSync(inRepo(REQUIRED_FILE), "utf8"));
    for (const path of [...(required["*"] ?? []), ...(required[repoName] ?? [])]) {
      if (!existsSync(join(repoDir, path))) fail(`required doc missing: ${path}`);
    }
  } else {
    fail(`required-docs list not found: ${REQUIRED_FILE}`);
  }

  // 0. Docs map.
  let map = [];
  if (existsSync(inRepo(MAP_FILE))) {
    const parsed = parseDocsMap(readFileSync(inRepo(MAP_FILE), "utf8"));
    parsed.errors.forEach(fail);
    map = parsed.entries
      .filter((e) => e.code && e.docs.length > 0)
      .map((e) => ({ ...e, codeRe: globToRegExp(e.code), docsRe: e.docs.map(globToRegExp) }));
  }

  // 1 and 2. Pull-request rules.
  if (env.BASE_SHA && env.HEAD_SHA) {
    const labels = new Set(JSON.parse(env.PR_LABELS_JSON || "[]"));
    if (labels.has(SKIP_LABEL)) {
      console.log(`docs-check: label ${SKIP_LABEL} present; the reviewer must accept the stated reason.`);
    } else {
      const changed = execFileSync(
        "git",
        ["-C", repoDir, "diff", "--name-only", "--no-renames", `${env.BASE_SHA}...${env.HEAD_SHA}`],
        { encoding: "utf8" },
      ).split("\n").filter(Boolean);
      const isSynced = (f) => SYNCED_FILES.has(f);
      const dependencyOnly = labels.has(DEPENDENCY_LABEL) && changed.every((f) => DEPENDENCY_FILE.test(f));
      if (!dependencyOnly && MAP_RULE_ENABLED) {
        for (const entry of map) {
          const hits = changed.filter((f) => entry.codeRe.test(f) && !isSynced(f));
          if (hits.length === 0) continue;
          if (!changed.some((f) => entry.docsRe.some((re) => re.test(f)))) {
            const shown = hits.slice(0, 3).join(", ") + (hits.length > 3 ? ", …" : "");
            fail(`code changed under "${entry.code}" (${shown}) without a change in: ${entry.docs.join(", ")}`);
          }
        }
      }
      const type = conventionalType(env.PR_TITLE);
      const onlySynced = changed.length > 0 && changed.every(isSynced);
      if (!changed.includes("CHANGELOG.md") && !NO_CHANGELOG_TYPES.has(type) && !onlySynced && !dependencyOnly) {
        fail(
          `CHANGELOG.md has no entry and the pull-request title type "${type ?? "none"}" is not one of ${[...NO_CHANGELOG_TYPES].join("/")}`,
        );
      }
    }
  }

  if (failures.length > 0) {
    failures.forEach((f) => console.log(`::error::docs-check: ${f}`));
    process.exit(1);
  }
  console.log(`docs-check structure: ok (${repoName}${env.BASE_SHA ? ", pull request rules applied" : ""})`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  run(resolve(process.argv[2] ?? "."));
}
