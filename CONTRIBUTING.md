# Contributing to dify-custom-rbac

Thanks for your interest in improving **dify-custom-rbac**! This document explains
how to report issues, propose changes, and what to expect from the project's
maintenance process.

## Code of conduct

Please be respectful and constructive. Assume good intent, keep discussion
focused on the technical problem, and help keep this a welcoming project for
everyone.

## Project maintenance model

This is a community-maintained open-source project. To keep quality and security
high, **all changes go through maintainer review**:

- **Issue triage:** A maintainer reviews and triages every new issue — applying
  labels, setting priority, asking for missing information, and deciding whether
  it is accepted, needs discussion, or is out of scope.
- **Pull request review:** Every pull request is **reviewed by a maintainer**
  before it can be merged. The maintainer may approve, request changes, ask
  questions, or decline a PR that is out of scope.
- **Merge & release authority:** Only maintainers merge pull requests and cut
  releases/tags.
- **Response expectations:** This is a best-effort, volunteer-run project. Please
  allow reasonable time for triage and review, and feel free to bump a stale
  thread politely.

## Ways to contribute

- Report a bug (use the **Bug report** issue template).
- Suggest a feature or improvement (use the **Feature request** template).
- Improve documentation (README, DEPLOYMENT, comments).
- Submit a fix or enhancement via a pull request.

## Reporting bugs

Open an issue with the **Bug report** template and include:

- Your **Dify version / commit** and how it was deployed (Docker Compose, custom
  images, etc.).
- Which script/mode you ran (e.g. `apply-dify-rbac.sh --auto`).
- Steps to reproduce.
- Expected vs. actual behaviour.
- Relevant logs — **redact any secrets or credentials first**.

## Suggesting features

Use the **Feature request** template. Describe the problem/motivation first, then
a proposed solution and any alternatives you considered.

## Development setup

This repository is tooling (Bash / Python / Node) that patches a **separate**
Dify installation. To test changes end to end you need a working self-hosted Dify
(Docker Compose) environment.

Before submitting, please lint and scan locally:

```bash
# Lint all shell scripts (CI enforces this)
shellcheck ./*.sh

# Secret scan (CI also runs this on push/PR)
gitleaks detect --source . --redact
```

## Pull request process

1. Fork the repository and create a focused branch (`feature/...` or `fix/...`).
2. Keep changes small and self-contained; one logical change per PR.
3. Make sure `shellcheck ./*.sh` passes locally — CI will block otherwise.
4. **Never commit secrets, `.env` files, credentials, or backup directories.**
5. Update `README.md` / `README_ja.md` and `CHANGELOG.md` when behaviour changes.
6. Open the PR using the template and link any related issue (e.g. `Closes #12`).
7. A maintainer will **review and triage** your PR. Address feedback by pushing
   additional commits to the same branch.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/) style is encouraged:
`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, `ci:`, etc.

## Security issues

**Do not** open public issues for security vulnerabilities. Please follow the
process in [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions will be licensed under the
project's [Apache License 2.0](LICENSE).
