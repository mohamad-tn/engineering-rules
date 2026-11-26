# React Native and Expo

Engine: the Node engine plus two mobile gates. Framework detection: `expo` or `react-native`.

| Gate | Runs |
|---|---|
| secrets-files | `check-tracked-secrets.mjs`: fails on a tracked keystore, credentials file or private key, a literal signing password, or a cleartext `http://` URL (loopback hosts allowed) |
| expo-export | `expo export --platform android` (Expo only): a release bundle must build |

All Node gates apply (see [node.md](node.md)).

## Recommended setup

- Signing material lives in a secret store or your build service. Never in git.
- Environment config (API domain, certificate pins) comes from environment variables, not from the repository.
- Build the installable test builds on demand and publish a SHA-256 next to them (a `workflow_dispatch`
  workflow; keep a documented fallback builder for when your build service is down or out of quota).
- Release-mode checks before publishing: no console logging, no developer menu, no cleartext traffic, certificate pins present.

## CI

`templates/stacks/react-native/ci.yml`. Native builds (APK or IPA) are not part of the default gates because
they need platform SDKs and signing; add them as a separate, manually triggered workflow.
