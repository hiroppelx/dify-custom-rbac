# dify-custom-rbac

🔐 **Restrict Dify log access to Owner/Admin roles only — with one command.**

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![ShellCheck](https://github.com/hiroppelx/dify-custom-rbac/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/hiroppelx/dify-custom-rbac/actions/workflows/shellcheck.yml)
[![gitleaks](https://github.com/hiroppelx/dify-custom-rbac/actions/workflows/gitleaks.yml/badge.svg)](https://github.com/hiroppelx/dify-custom-rbac/actions/workflows/gitleaks.yml)
[![For Dify self-hosted](https://img.shields.io/badge/for-Dify%20self--hosted-1C64F2)](https://github.com/langgenius/dify)

> [日本語版はこちら / Japanese version](README_ja.md)

By default, self-hosted Dify lets any Editor-or-above user view workflow and
conversation logs. **dify-custom-rbac** adds an authorization check so that only
**Owner** and **Admin** roles can access those logs.

> **Disclaimer:** This is an independent, community-maintained tool. It is **not**
> affiliated with, endorsed by, or sponsored by LangGenius / the Dify project. No
> Dify source code is redistributed here; the scripts patch *your own* Dify
> installation.

---

## Table of contents

- [How it works](#how-it-works)
- [Compatibility](#compatibility)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Rollback](#rollback)
- [Verification](#verification)
- [Upgrading Dify](#upgrading-dify)
- [Custom Docker images](#custom-docker-images)
- [Limitations & caveats](#limitations--caveats)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## How it works

The tool applies a small, well-defined authorization check to Dify's log
endpoints and UI.

### Backend (API)

- **`api/controllers/console/app/workflow_app_log.py`** — restrict workflow log
  access to Owner/Admin.
- **`api/controllers/console/app/conversation.py`** — restrict conversation log
  access to Owner/Admin (4 endpoints: completion/chat conversation list & detail).

The check is uniform:

```python
from models.account import TenantAccountRole
if not TenantAccountRole.is_privileged_role(current_user.current_tenant_account.role):
    raise Forbidden("Only owner or admin can view logs")
```

Editor/Member users receive **`403 Forbidden`**.

### Frontend (Web, optional)

- Hides the **Logs** navigation item for non-privileged roles and redirects them
  away from the log route (`web/context/app-context.tsx`,
  `web/app/(commonLayout)/app/(appDetailLayout)/[appId]/layout-main.tsx`).

The frontend change is defense-in-depth/UX; the backend check is the actual
enforcement.

### Two ways to apply

| Approach | Script | What it does |
| --- | --- | --- |
| **Runtime patch** (quickest) | `apply-dify-rbac.sh` | Patches files in the running API container and restarts it. Creates automatic backups. |
| **Custom images** (reproducible) | `build-custom-images.sh` + `docker-compose.override.yml` | Build `dify-*-custom-rbac` images from a Dify source tree **you patch first** (see [Custom Docker images](#custom-docker-images)). No in-place patching of a running container. |

---

## Compatibility

`dify-custom-rbac` targets **self-hosted Dify deployed via Docker Compose**.

Because it changes behaviour by patching specific Dify source files and code
patterns, **its compatibility is tied to your Dify version**. It relies on the
following code being present and matching in your installation:

| Layer    | File | Pattern it relies on |
| -------- | ---- | -------------------- |
| Backend  | `api/controllers/console/app/workflow_app_log.py` | `def get(self, app_model: App)` |
| Backend  | `api/controllers/console/app/conversation.py` | `if not current_user.is_editor:` |
| Backend  | `models/account.py` | `TenantAccountRole.is_privileged_role()` |
| Frontend | `web/context/app-context.tsx` | `isCurrentWorkspaceEditor` / `isCurrentWorkspaceOwner` |
| Frontend | `web/app/(commonLayout)/app/(appDetailLayout)/[appId]/layout-main.tsx` | log nav item + route guard |

**There is intentionally no single "supported version" pin.** A newer or older
Dify release may move or rename this code. Before applying to production:

1. Run the non-destructive checks first:
   ```bash
   ./apply-dify-rbac.sh --verify-only      # inspect current state
   ./dify-integrated-upgrade.sh --dry-run  # preview upgrade actions
   ```
2. The patchers print **`WARNING: Search pattern not found`** when a target
   pattern has changed — treat that as *"not compatible until the pattern is
   updated."*
3. **Pin your Dify image tag** (avoid `latest`) so behaviour is reproducible.

If you verify this against a specific Dify version, please share it via an issue
or PR so we can document known-good versions.

---

## Requirements

- Self-hosted **Dify** running with **Docker Compose** (`docker compose`).
- A running Dify **API container**.
- **Bash** (Linux/macOS). Container access via `docker` for the runtime-patch
  approach.
- For the custom-image approach: ability to build images (Node toolchain is used
  inside `Dockerfile.web` via `npm run build`).

---

## Installation

```bash
# Download the main script and make it executable
curl -L https://raw.githubusercontent.com/hiroppelx/dify-custom-rbac/main/apply-dify-rbac.sh -o apply-dify-rbac.sh
chmod +x apply-dify-rbac.sh
```

> **Security tip:** This is a security tool — **read the script before running
> it** (`less apply-dify-rbac.sh`) instead of piping `curl` straight into a
> shell. See [SECURITY.md](SECURITY.md).

---

## Usage

```bash
# Fully automated (recommended once you trust your environment)
./apply-dify-rbac.sh --auto

# Step-by-step, with confirmations
./apply-dify-rbac.sh --interactive

# Only check the current RBAC state (non-destructive)
./apply-dify-rbac.sh --verify-only

# Point at a non-default Dify install
./apply-dify-rbac.sh --dify-path /custom/path/dify --auto

# Undo changes (restore from the latest automatic backup)
./apply-dify-rbac.sh --rollback

# Help
./apply-dify-rbac.sh --help
```

The script auto-detects the Dify directory and Docker containers, creates a
timestamped backup, applies the patches, restarts the API container, verifies the
result, and prints a report.

---

## Rollback

Every apply creates a timestamped backup under `/tmp/dify-rbac-backup-*`, so you
can always revert.

```bash
# Roll back the most recent apply
./apply-dify-rbac.sh --rollback

# List available backups
ls -la /tmp/dify-rbac-backup-*
```

For the standalone source patchers, use their `revert` subcommands:

```bash
python3 backend-rbac-patch.py revert
node frontend-rbac-patch.js revert
```

---

## Verification

### Role-based access matrix

| Role       | Log API access | Verification | Expected result |
| ---------- | -------------- | ------------ | --------------- |
| **Owner**  | ✅ Allowed     | Open the logs page | Normal display |
| **Admin**  | ✅ Allowed     | Open the logs page | Normal display |
| **Editor** | ❌ Denied      | Open the logs page | `403 Forbidden` |
| **Member** | ❌ Denied      | Open the logs page | `403 Forbidden` |

### Steps

```bash
# 1. Automated check
./apply-dify-rbac.sh --verify-only

# 2. Manual check
#  - Log in as Owner/Admin -> logs are visible.
#  - Log in as Editor/Member -> access is denied (403).
```

---

## Upgrading Dify

Dify upgrades can overwrite the patched files, so re-apply RBAC after upgrading.
The integrated upgrade script does this for you and keeps backups:

```bash
curl -L https://raw.githubusercontent.com/hiroppelx/dify-custom-rbac/main/dify-integrated-upgrade.sh -o dify-integrated-upgrade.sh
chmod +x dify-integrated-upgrade.sh

./dify-integrated-upgrade.sh --dry-run      # preview only (no changes)
./dify-integrated-upgrade.sh --interactive  # step-by-step
./dify-integrated-upgrade.sh --auto         # automated
./dify-integrated-upgrade.sh --skip-rbac --auto  # upgrade Dify only
```

It backs up your configuration and volumes, temporarily rolls back RBAC, upgrades
Dify, re-applies RBAC, and verifies the result.

<details>
<summary>Manual upgrade procedure</summary>

```bash
# 1. Roll back current RBAC changes
./apply-dify-rbac.sh --rollback

# 2. Upgrade Dify
cd /path/to/dify
git pull origin main
docker compose pull
docker compose up -d

# 3. Re-apply RBAC
cd /path/to/dify-custom-rbac
./apply-dify-rbac.sh --auto

# 4. Verify
./apply-dify-rbac.sh --verify-only
```
</details>

---

## Custom Docker images

For reproducible deployments you can build pre-patched images instead of patching
at runtime. **`build-custom-images.sh` does not patch anything by itself** — it
builds images from a Dify **source tree** (the sibling `../dify` directory), which
must already contain the RBAC changes.

> **Heads-up — patch the tree you build from.** The standalone source patchers
> (`backend-rbac-patch.py` / `frontend-rbac-patch.js`) currently default to
> patching `/root/dify` and take no path argument, while `build-custom-images.sh`
> builds from `../dify`. Make sure the tree you build from is actually patched
> (e.g. place your Dify checkout at `/root/dify`, or apply the equivalent edits to
> your `../dify` tree), **then** build.

```bash
# Build images from an already-patched Dify source tree (the sibling ../dify)
./build-custom-images.sh
# Produces: dify-api-custom-rbac:latest, dify-web-custom-rbac:latest

# Deploy using the override file in your Dify directory
cp docker-compose.override.yml /path/to/dify/
docker compose up -d
```

> **Always verify the built image enforces RBAC before deploying** — an unpatched
> source tree produces `dify-*-custom-rbac` images that do **not** enforce RBAC
> despite their name:
>
> ```bash
> docker run --rm dify-api-custom-rbac:latest \
>   grep -q "is_privileged_role" \
>   /app/api/controllers/console/app/workflow_app_log.py \
>   && echo "RBAC present" || echo "NOT patched — do not deploy"
> ```
>
> For most users the runtime-patch route (`apply-dify-rbac.sh --auto`, which
> auto-detects your Dify and supports `--dify-path`) is simpler and avoids this.

See [DEPLOYMENT.md](DEPLOYMENT.md) for a full, step-by-step deployment guide
(prerequisites, environment configuration, nginx hardening, monitoring, and a
completion checklist).

---

## Limitations & caveats

- **Version coupling.** The tool patches Dify's internal source/UI patterns; a
  Dify upgrade can break it. Always re-verify after upgrading.
- **Not affiliated with Dify.** Independent community tool; not produced or
  endorsed by LangGenius / the Dify project.
- **`latest` base images.** `Dockerfile.api` / `Dockerfile.web` build
  `FROM langgenius/dify-*:latest`. Pin a version for reproducible builds.
- **Runtime patching restarts the API container,** causing a brief interruption.
  The custom-image route avoids in-place patching.
- **Frontend changes require a web rebuild** (`Dockerfile.web` runs
  `npm run build`), which takes time and resources.
- **Scope is log endpoints only.** It restricts workflow and conversation logs to
  Owner/Admin. It is not a general-purpose RBAC system for other Dify features.
- **Self-hosted only.** Requires file/container access; not applicable to Dify
  Cloud.
- **The test suites** target the patched Dify code and need a Dify environment /
  its dependencies to run; they are references rather than a standalone CI gate
  in this repository.

---

## Security

- Read [SECURITY.md](SECURITY.md) for the vulnerability-reporting process and the
  threat model.
- Prefer **download-and-review** over `curl | bash` for any script in this repo.
- CI runs **ShellCheck** and **gitleaks** (secret scanning, full history) on every
  push and pull request.

---

## Troubleshooting

<details>
<summary>API container fails to start after applying</summary>

```bash
docker logs <api-container> --tail 50
docker restart <api-container>
sleep 30
./apply-dify-rbac.sh --verify-only
```
</details>

<details>
<summary>Editor can still access logs</summary>

```bash
# Confirm the patch is present, re-apply if needed
./apply-dify-rbac.sh --verify-only
./apply-dify-rbac.sh --auto
```
</details>

<details>
<summary>Admin cannot access logs</summary>

Verify the user's role in the Dify admin panel, clear the browser cache, and try
a different browser.
</details>

<details>
<summary><code>WARNING: Search pattern not found</code></summary>

Your Dify version likely changed the targeted code. See
[Compatibility](#compatibility). Revert any partial changes and update the
patterns, or open an issue with your Dify version.
</details>

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md).

This is a community-maintained project: **a maintainer reviews every pull request
and triages every issue** before changes are accepted. Only maintainers merge PRs
and cut releases.

Before submitting:

```bash
shellcheck ./*.sh                       # lint (CI enforces this)
gitleaks detect --source . --redact     # secret scan
```

---

## License

This project's tooling is licensed under the [Apache License 2.0](LICENSE). See
[`NOTICE`](NOTICE) for attribution. (Dify itself is distributed under a *modified*
Apache License 2.0 with additional terms — review Dify's own
[LICENSE](https://github.com/langgenius/dify/blob/main/LICENSE) for the conditions
that apply to your deployment.)

---

## Languages

- [English](README.md) (this file)
- [日本語 / Japanese](README_ja.md)
