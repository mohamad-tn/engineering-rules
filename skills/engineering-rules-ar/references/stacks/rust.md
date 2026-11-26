<!-- rtl -->
<div dir="rtl">

# Rust

المحرك: `scripts/stacks/rust.sh` (Cargo، بما فيه مساحات العمل).

| البوابة | ما تشغّله |
|---|---|
| `deps` | `cargo fetch --locked` (برنامج تنفيذي بدون `Cargo.lock` يعني `FAIL`) |
| `format` | `cargo fmt --all -- --check` |
| `lint` | `cargo clippy --all-targets --locked -- -D warnings` |
| `test` | `cargo test --locked` |
| `build` | `cargo build --locked` |
| `audit` | `cargo audit`، أو `cargo deny check advisories` عند وجود `deny.toml` |

## الإعداد الموصى به

- ارفع `Cargo.lock` للبرامج التنفيذية.
- إعدادات اختيارية: `templates/stacks/rust/configs/` (الملفان `rustfmt.toml` و`deny.toml`).
- ثبّت `cargo-audit` بإصدار محدد في الـ CI.

## التكامل المستمر (CI)

الملف `templates/stacks/rust/ci.yml` (يثبّت أحدث إصدار مستقر مع `clippy` و`rustfmt`).

</div>
