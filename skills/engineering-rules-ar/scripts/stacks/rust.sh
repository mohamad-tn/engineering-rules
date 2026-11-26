#!/usr/bin/env bash
# shellcheck shell=bash
# Rust engine (Cargo): binaries, libraries, workspaces, Axum / Actix / Tauri backends.

run_rust() {
  have cargo || { notrun deps "cargo is not installed"; return 0; }
  echo "  rust: $(rustc --version 2>/dev/null | cut -d' ' -f2)"
  local locked=()
  if [[ -f Cargo.lock ]]; then
    locked=(--locked)
  elif [[ -f src/main.rs ]] || grep -q '^\[\[bin\]\]' Cargo.toml; then
    fail deps "Cargo.lock is missing: commit it for binaries"
    return 0
  else
    warn lockfile "library without Cargo.lock: dependency versions are not pinned for CI"
  fi

  gate_net deps -- cargo fetch "${locked[@]}"
  if have rustfmt || cargo fmt --version >/dev/null 2>&1; then
    gate format -- cargo fmt --all -- --check
  else
    notrun format "rustfmt is not installed (rustup component add rustfmt)"
  fi
  if have cargo-clippy || cargo clippy --version >/dev/null 2>&1; then
    gate lint -- cargo clippy --all-targets "${locked[@]}" -- -D warnings
  else
    notrun lint "clippy is not installed (rustup component add clippy)"
  fi
  na types "covered by the compiler and clippy"
  gate test -- cargo test "${locked[@]}"
  gate build -- cargo build "${locked[@]}"

  if have cargo-audit || cargo audit --version >/dev/null 2>&1; then
    gate_net audit -- cargo audit
  elif [[ -f deny.toml ]] && { have cargo-deny || cargo deny --version >/dev/null 2>&1; }; then
    gate_net audit -- cargo deny check advisories
  else
    notrun audit "cargo-audit is not installed (cargo install cargo-audit)"
  fi
}
