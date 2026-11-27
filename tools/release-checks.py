#!/usr/bin/env python3
"""Fail closed unless the newest main/push CI run for this commit is complete.

All four required checks must belong to the same CI run/attempt/check suite and
GitHub Actions app. Successful jobs with missing logs or skipped tests are not
release evidence. This reads GitHub APIs only; it never creates statuses/releases.
"""
import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

REQUIRED = {"static checks": 1, "core gates": 3, "stack gates (real toolchains)": 1, "installer, doctor and demo": 4}
WORKFLOW_PATH = ".github/workflows/ci.yml"
ACTIONS_APP_ID = 15368
MAX_RESPONSE = 32 * 1024 * 1024


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class API:
    def __init__(self, repository, token):
        self.base = f"https://api.github.com/repos/{repository}"
        self.token = token
        self.opener = urllib.request.build_opener(NoRedirect)

    def request(self, path):
        if not path.startswith("/") or ".." in path:
            raise ValueError("invalid API path")
        request = urllib.request.Request(self.base + path, headers={
            "Authorization": f"Bearer {self.token}", "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "engineering-rules-release-checks",
        })
        return self.opener.open(request, timeout=30)

    @staticmethod
    def body(response):
        body = response.read(MAX_RESPONSE + 1)
        if len(body) > MAX_RESPONSE:
            raise ValueError("API/log response exceeds release verification limit")
        return body

    def get(self, path):
        with self.request(path) as response:
            return json.loads(self.body(response))

    def list(self, path, key):
        items = []
        separator = "&" if "?" in path else "?"
        for page in range(1, 101):
            result = self.get(f"{path}{separator}per_page=100&page={page}")[key]
            items.extend(result)
            if len(result) < 100:
                return items
        raise ValueError("pagination exceeds release verification limit")

    def logs(self, job_id):
        try:
            with self.request(f"/actions/jobs/{job_id}/logs") as response:
                return self.body(response).decode("utf-8")
        except urllib.error.HTTPError as error:
            if error.code != 302:
                raise
            location = error.headers.get("Location", "")
            target = urllib.parse.urlsplit(location)
            if target.scheme != "https" or not target.hostname or target.username or target.password:
                raise ValueError("unsafe log redirect") from None
            # Signed log storage gets NO API Authorization header, including on
            # subsequent redirects; never forward the repository token to storage.
            with urllib.request.urlopen(urllib.request.Request(location), timeout=30) as response:
                return self.body(response).decode("utf-8")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_logs(text, name):
    lines = [re.sub(r"^\d{4}-\d\d-\d\dT[^ ]+ +", "", line).strip() for line in text.splitlines()]
    require(not any(re.match(r"SKIP\s", line) for line in lines), f"{name}: tests/tools were skipped")
    summaries = [re.fullmatch(r"passed: ([0-9]+)  failed: ([0-9]+)  skipped: ([0-9]+)", line) for line in lines]
    summaries = [s for s in summaries if s]
    require(summaries and all(int(s[1]) > 0 and s[2] == "0" and s[3] == "0" for s in summaries), f"{name}: missing/failed/skipped test summary")
    require(sum(line == "ALL TESTS PASSED" for line in lines) == REQUIRED[name], f"{name}: missing expected suite completion markers")


def verify(api, repository, sha):
    require(re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository) is not None, "invalid repository")
    require(re.fullmatch(r"[0-9a-f]{40}", sha) is not None, "commit must be a full SHA")
    workflow = api.get("/actions/workflows/ci.yml")
    require(workflow.get("path") == WORKFLOW_PATH and workflow.get("name") == "ci" and workflow.get("state") == "active", "unexpected CI workflow")
    runs = api.list(f"/actions/workflows/{workflow['id']}/runs?head_sha={sha}&event=push&branch=main", "workflow_runs")
    require(bool(runs), "no main/push CI run for the tag commit; run CI on main first")
    run = max(runs, key=lambda item: item["id"])
    require(run.get("workflow_id") == workflow["id"] and run.get("path") == WORKFLOW_PATH, "run is from an unexpected workflow")
    require(run.get("head_sha") == sha and run.get("event") == "push" and run.get("head_branch") == "main", "run is not for the same main/tag commit")
    require(run.get("repository", {}).get("full_name") == repository and run.get("head_repository", {}).get("full_name") == repository, "unexpected run repository")
    # Overall CI can fail on experimental jobs. Only the four required jobs are
    # release gates, but a run that is still in progress is never accepted.
    require(run.get("status") == "completed", "newest CI run is not complete; retry release after CI finishes")
    attempt = run.get("run_attempt")
    require(isinstance(attempt, int) and attempt > 0 and isinstance(run.get("check_suite_id"), int), "run attempt/check suite is missing")
    jobs = api.list(f"/actions/runs/{run['id']}/attempts/{attempt}/jobs", "jobs")
    for name in REQUIRED:
        matching = [job for job in jobs if job.get("name") == name]
        require(len(matching) == 1, f"missing/duplicate required job: {name}")
        job = matching[0]
        require(job.get("head_sha") == sha and job.get("run_id") == run["id"] and job.get("run_attempt") == attempt, f"{name}: wrong commit/run/attempt")
        require(job.get("status") == "completed" and job.get("conclusion") == "success", f"{name}: required job did not succeed")
        require(job.get("steps") and all(step.get("status") == "completed" and step.get("conclusion") == "success" for step in job["steps"]), f"{name}: skipped/failed job step")
        prefix = f"https://api.github.com/repos/{repository}/check-runs/"
        url = job.get("check_run_url", "")
        require(url.startswith(prefix) and re.fullmatch(r"[0-9]+", url[len(prefix):]) is not None, f"{name}: invalid check URL")
        check = api.get("/check-runs/" + url[len(prefix):])
        require(check.get("head_sha") == sha and check.get("name") == name and check.get("check_suite", {}).get("id") == run["check_suite_id"], f"{name}: check is not from the same CI suite/commit")
        require(check.get("app", {}).get("id") == ACTIONS_APP_ID and check.get("app", {}).get("slug") == "github-actions", f"{name}: unexpected check app")
        require(check.get("status") == "completed" and check.get("conclusion") == "success", f"{name}: check did not succeed")
        validate_logs(api.logs(job["id"]), name)
    return {"commit": sha, "workflow": WORKFLOW_PATH, "run_id": run["id"], "run_attempt": attempt, "check_suite_id": run["check_suite_id"], "app_id": ACTIONS_APP_ID, "required": list(REQUIRED)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--commit", required=True)
    args = parser.parse_args()
    try:
        token = os.environ.get("GH_TOKEN")
        require(bool(token), "read-only GH_TOKEN is required")
        result = verify(API(args.repository, token), args.repository, args.commit)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (ValueError, OSError, KeyError, TypeError) as error:
        # Do not print redirected URLs, request bodies, headers, or credentials.
        print(f"release CI verification refused: {type(error).__name__}", file=sys.stderr)
        if isinstance(error, ValueError):
            print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
