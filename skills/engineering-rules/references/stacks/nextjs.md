# Next.js

Engine: the Node engine plus a client-bundle scan. Framework detection: `next` in `package.json`.

All Node gates apply (see [node.md](node.md)). Extra gate:

| Gate | Runs |
|---|---|
| bundle-scan | `scan-client-bundle.mjs`: fails when `.next/static` contains the private backend URL, its host, or a `NEXT_PUBLIC_` marker. Needs `API_BASE_URL` and a finished build. |

## Why the bundle scan matters

A private API URL, an internal host name or a key that ends up in client JavaScript is public
the moment you deploy. The scan is a cheap last line of defence after `next build`.

## Recommended setup

- The browser talks to its own origin; a server layer (route handlers, server actions) calls the backend.
- Keep the few hosts the browser may contact in a reviewed allowlist (`templates/stacks/nextjs/configs/public-surface.yml`).
- `NEXT_TELEMETRY_DISABLED=1` is set by the gates so builds do not call out.

## CI

`templates/stacks/nextjs/ci.yml` sets `API_BASE_URL` for the scan. Replace it with your private
backend URL (it is only a string to search for, not a secret to store).

## Real result

The Next.js fixture in `tests/fixtures/nextjs` builds with the real compiler, and the `audit`
gate reports the advisories of its deliberately old Next.js version.
