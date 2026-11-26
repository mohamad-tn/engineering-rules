/**
 * SHA-256 lock helper for vendored artifacts that must stay byte-identical
 * across languages or repositories (fixtures, catalogs). Import it from a
 * check script, or call it from a test.
 *
 * Lock file format: first whitespace-separated field is the lowercase hex
 * digest (the output of `sha256sum <file>` works as-is).
 *
 * Example check script:
 *   import { assertSha256Lock } from "./assert-sha256-lock.mjs";
 *   assertSha256Lock("fixtures/data.json", "fixtures/data.json.sha256",
 *     "Regenerate the file in every language, then run `sha256sum` and update the lock.");
 *
 * @param {string} artifactPath - Path to the locked file.
 * @param {string} lockPath - Path to the `.sha256` lock file.
 * @param {string} mismatchHint - Guidance printed when the digests differ.
 * @returns {string} Actual hex digest (lowercase).
 */
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

export function assertSha256Lock(artifactPath, lockPath, mismatchHint) {
  const expected = readFileSync(lockPath, "utf8").trim().split(/\s+/)[0]?.toLowerCase();
  const actual = createHash("sha256").update(readFileSync(artifactPath)).digest("hex");
  if (!expected || actual !== expected) {
    console.error(
      `${artifactPath} sha256 mismatch.\nexpected: ${expected ?? "(missing)"}\nactual:   ${actual}\n${mismatchHint}`,
    );
    process.exit(1);
  }
  return actual;
}
