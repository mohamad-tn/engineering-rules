# Node.js, React, Vue, Angular, Svelte, NestJS, Express

Engine: `scripts/stacks/node.sh`. Detects the framework from `package.json` and the package
manager from the lockfile (npm, pnpm, yarn classic or berry, bun).

| Gate | Runs |
|---|---|
| deps | `npm ci` / `pnpm install --frozen-lockfile` / `yarn install --immutable` / `bun install --frozen-lockfile`. No lockfile is a FAIL. |
| format | script `format:check`, else Prettier or Biome if configured |
| lint | script `lint`, else ESLint or Biome if configured |
| types | script `typecheck`, else `tsc --noEmit` when `tsconfig.json` exists |
| test | script `test` (the npm placeholder "no test specified" counts as no tests) |
| build | script `build` |
| audit | `npm audit --omit=dev` / `pnpm audit --prod` / `yarn audit`, at `AUDIT_LEVEL` |
| dup | `jscpd` when `.jscpd.json` exists |

## Recommended setup

- Pin the runtime: `.nvmrc` plus `"engines"` plus `.npmrc` with `engine-strict=true`.
- Use exact versions in `package.json` and commit the lockfile.
- Give each gate a script with the standard name so CI and your laptop run the same thing.
- Opt-in configs: `templates/stacks/node/configs/` (`.jscpd.json`, `.npmrc`).

## CI

`templates/stacks/node/ci.yml` (setup-node, then `stack-gates.sh --engine node`). For pnpm or
yarn add a `corepack enable` step before the gates. The `scope` step skips the heavy work for
docs-only pull requests while keeping the required check reporting.

## Notes

- Workspaces: the root runs everything; member packages are not run twice.
- React, Vue, Angular, Svelte and Vite have no special gates beyond `build`. Set
  `CLIENT_BUNDLE_DIR` and `API_BASE_URL` to also scan the built bundle for a private backend host.
