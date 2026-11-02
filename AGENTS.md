## Language

- The app UI, including every label and message, is in English.
- Issues, docs, glossary and ADRs are written in English. Existing Italian docs are translated only when asked.
- Chat with the user follows their language.

## Before closing an issue

- `make test` must pass.
- If the issue touches the app, `make smoke` must print `smoke ok` (local only: needs the Accessibility permission for the terminal), then run `docs/manual-checklist.md`.

## Concurrency

- Code that receives callbacks from C APIs or runs on other threads lives in `Sources/BackgroundAdapters` (nonisolated by default), never in `Sources/Downtab` (main-actor by default). Pass C callbacks as named functions, not inline closures.

## Agent skills

### Issue tracker

Le issue stanno su GitHub (`iacoware/downtab`) e si gestiscono con `gh`. See `docs/agents/issue-tracker.md`.

### Triage labels

Le cinque label canoniche di default (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` e `docs/adr/` alla radice. See `docs/agents/domain.md`.
