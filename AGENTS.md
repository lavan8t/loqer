# Agent Instructions

- **Package Manager**: Always use `bun` and `bunx`. Never use `npm`, `npx`, `yarn`, or `pnpm`.
- **Git Commits**: Always commit with `--no-gpg-sign`.

## Agent skills

### Issue tracker

GitHub issues tracked via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical five-role triage labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repository layout (`GLOSSARY.md` + `docs/adr/`). See `docs/agents/domain.md`.
