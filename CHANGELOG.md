# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_Nothing yet._

## [1.0.0] - 2026-05-31

> Draft release notes for the first public release. Adjust the date to the actual
> release/tag date before publishing.

First public release of **dify-custom-rbac** — tooling that restricts Dify log
access (workflow logs and conversation logs) to **Owner/Admin** roles only on
self-hosted (Docker Compose) deployments.

### Added

- **`apply-dify-rbac.sh`** — one-command script to apply, verify, and roll back
  the RBAC restriction on a running Dify deployment, with automatic timestamped
  backups. Modes: `--auto`, `--interactive`, `--verify-only`, `--rollback`,
  `--dify-path`, `--help`.
- **`dify-integrated-upgrade.sh`** — upgrade Dify while preserving the RBAC
  customization, with pre-/post-upgrade validation, configuration/volume backups,
  and rollback guidance. Modes: `--auto`, `--interactive`, `--dry-run`,
  `--skip-rbac`, `--force`, `--dify-path`, `--rbac-script`, `--backup-root`.
- **`backend-rbac-patch.py`** — idempotent backend patcher for
  `workflow_app_log.py` and `conversation.py` (Owner/Admin-only log access),
  with a `revert` subcommand.
- **`frontend-rbac-patch.js`** — frontend patcher that hides the log menu and
  guards the log route for non-privileged roles, with a `revert` subcommand.
- **Custom image build path** — `build-custom-images.sh`, `Dockerfile.api`,
  `Dockerfile.web`, and `docker-compose.override.yml` to build and run images
  from a pre-patched Dify source tree instead of patching at runtime.
- **`nginx.custom.conf`** — optional rate limiting and security headers for log
  endpoints.
- **Tests** — `test_rbac_backend.py` and `test_rbac_frontend.test.tsx` as
  reference suites for the patched behaviour.
- **Documentation** — English (`README.md`) and Japanese (`README_ja.md`)
  READMEs, plus a detailed `DEPLOYMENT.md`.
- **Project governance & quality** — `LICENSE` (Apache-2.0), `NOTICE`,
  `CONTRIBUTING.md`, `SECURITY.md`, issue/PR templates, and CI workflows
  (ShellCheck + gitleaks) running on push and pull request.

### Security

- Restricts the workflow-log and conversation-log API endpoints to Owner/Admin
  via `TenantAccountRole.is_privileged_role()`, returning `403 Forbidden` to
  Editor/Member users. Frontend hides the log navigation and redirects
  non-privileged users away from the log route (defense in depth).

### Known limitations

- Compatibility is coupled to Dify's internal source layout and UI patterns;
  verify against your Dify version and pin image tags. See the README
  "Compatibility" and "Limitations" sections.

[Unreleased]: https://github.com/hiroppelx/dify-custom-rbac/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/hiroppelx/dify-custom-rbac/releases/tag/v1.0.0
