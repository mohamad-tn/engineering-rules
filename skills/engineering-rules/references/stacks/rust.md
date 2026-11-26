# Rust

Engine: `scripts/stacks/rust.sh` (Cargo, including workspaces).

| Gate | Runs |
|---|---|
| deps | `cargo fetch --locked` (a binary without `Cargo.lock` is a FAIL) |
| format | `cargo fmt --all -- --check` |
| lint | `cargo clippy --all-targets --locked -- -D warnings` |
| test | `cargo test --locked` |
| build | `cargo build --locked` |
| audit | `cargo audit`, or `cargo deny check advisories` when `deny.toml` exists |

## Recommended setup

- Commit `Cargo.lock` for binaries.
- Opt-in configs: `templates/stacks/rust/configs/` (`rustfmt.toml`, `deny.toml`).
- Install `cargo-audit` at a pinned version in CI.

## CI

`templates/stacks/rust/ci.yml` (installs the stable toolchain with clippy and rustfmt).
