#!/usr/bin/env python3
"""Unit checks for release CI evidence parsing and run binding; no network access is used."""
from importlib.machinery import SourceFileLoader

CHECKS = SourceFileLoader("release_checks", "tools/release-checks.py").load_module()
REPOSITORY = "example/engineering-rules"
COMMIT = "a" * 40


class FakeAPI:
    """Small in-memory API surface for verify(); it never opens a connection."""

    def __init__(
        self,
        *,
        run_sha=COMMIT,
        run_status="completed",
        job_sha=COMMIT,
        job_attempt=2,
        check_sha=COMMIT,
        check_suite_id=123,
        app_id=CHECKS.ACTIONS_APP_ID,
    ):
        self.workflow_id = 10
        self.run_id = 20
        self.run_attempt = 2
        self.check_suite_id = 123
        self.job_ids = {}
        self.check_runs = {}
        self.logs_by_job = {}
        self.list_paths = []
        self.workflow = {
            "id": self.workflow_id,
            "path": CHECKS.WORKFLOW_PATH,
            "name": "ci",
            "state": "active",
        }
        self.run = {
            "id": self.run_id,
            "workflow_id": self.workflow_id,
            "path": CHECKS.WORKFLOW_PATH,
            "head_sha": run_sha,
            "event": "push",
            "head_branch": "main",
            "repository": {"full_name": REPOSITORY},
            "head_repository": {"full_name": REPOSITORY},
            "status": run_status,
            "run_attempt": self.run_attempt,
            "check_suite_id": self.check_suite_id,
        }
        self.jobs = []
        for index, name in enumerate(CHECKS.REQUIRED):
            job_id = 30 + index
            check_id = 40 + index
            check_url = f"https://api.github.com/repos/{REPOSITORY}/check-runs/{check_id}"
            self.job_ids[name] = job_id
            self.jobs.append(
                {
                    "id": job_id,
                    "name": name,
                    "head_sha": job_sha,
                    "run_id": self.run_id,
                    "run_attempt": job_attempt,
                    "status": "completed",
                    "conclusion": "success",
                    "steps": [{"status": "completed", "conclusion": "success"}],
                    "check_run_url": check_url,
                }
            )
            self.check_runs[str(check_id)] = {
                "head_sha": check_sha,
                "name": name,
                "check_suite": {"id": check_suite_id},
                "app": {"id": app_id, "slug": "github-actions"},
                "status": "completed",
                "conclusion": "success",
            }
            markers = "ALL TESTS PASSED\n" * CHECKS.REQUIRED[name]
            self.logs_by_job[job_id] = f"passed: 2  failed: 0  skipped: 0\n{markers}"

    def get(self, path):
        if path == "/actions/workflows/ci.yml":
            return self.workflow
        if path.startswith("/check-runs/"):
            return self.check_runs[path.rsplit("/", 1)[1]]
        raise AssertionError(f"unexpected API GET path: {path}")

    def list(self, path, key):
        self.list_paths.append(path)
        if path.startswith("/actions/workflows/") and key == "workflow_runs":
            return [self.run]
        if path.startswith("/actions/runs/") and key == "jobs":
            return self.jobs
        raise AssertionError(f"unexpected API list path/key: {path} / {key}")

    def logs(self, job_id):
        return self.logs_by_job[job_id]


def must_reject(log, name="static checks"):
    try:
        CHECKS.validate_logs(log, name)
    except ValueError:
        return
    raise AssertionError(f"release evidence was incorrectly accepted for {name}: {log!r}")


def must_reject_verify(api):
    try:
        CHECKS.verify(api, REPOSITORY, COMMIT)
    except ValueError:
        return
    raise AssertionError("release evidence with mismatched run data was incorrectly accepted")


def main():
    good = "2026-11-27T12:00:00Z passed: 8  failed: 0  skipped: 0\n2026-11-27T12:00:01Z ALL TESTS PASSED\n"
    CHECKS.validate_logs(good, "static checks")
    must_reject("2026-11-27T12:00:00Z SKIP  missing tool\n" + good)
    must_reject("passed: 8  failed: 1  skipped: 0\nALL TESTS PASSED\n")
    must_reject("passed: 8  failed: 0  skipped: 1\nALL TESTS PASSED\n")
    must_reject("passed: 0  failed: 0  skipped: 0\nALL TESTS PASSED\n")
    must_reject("passed: 8  failed: 0  skipped: 0\n")
    must_reject("passed: 8  failed: 0  skipped: 0\nALL TESTS PASSED\nALL TESTS PASSED\n", "stack gates (real toolchains)")

    api = FakeAPI()
    result = CHECKS.verify(api, REPOSITORY, COMMIT)
    assert result["commit"] == COMMIT
    assert result["run_id"] == api.run_id
    assert result["run_attempt"] == api.run_attempt
    assert result["check_suite_id"] == api.check_suite_id
    assert any(f"/attempts/{api.run_attempt}/jobs" in path for path in api.list_paths)

    must_reject_verify(FakeAPI(check_sha="b" * 40))
    must_reject_verify(FakeAPI(run_sha="b" * 40))
    must_reject_verify(FakeAPI(job_attempt=1))
    must_reject_verify(FakeAPI(check_suite_id=999))
    must_reject_verify(FakeAPI(run_status="in_progress"))

    print("release CI evidence rejects skipped/failed logs and mismatched commit/run/attempt/check metadata")


if __name__ == "__main__":
    main()
