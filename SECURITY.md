# Security Policy

## Supported versions

This project follows a rolling-release model. Security fixes are applied to the
latest release and the `main` branch. Older tags are not maintained.

| Version                         | Supported |
| ------------------------------- | --------- |
| `main` / latest released tag    | ✅        |
| older tags                      | ❌        |

## Reporting a vulnerability

Please report security vulnerabilities **privately**. Do **not** open a public
issue, pull request, or discussion for a suspected vulnerability.

- **Preferred:** open a private report via GitHub Security Advisories —
  the "Report a vulnerability" button under the repository's **Security** tab.
- **Alternative:** contact the maintainer through the contact details listed on
  the maintainer's GitHub profile.

Please include:

- A description of the issue and its impact.
- Steps to reproduce or a proof of concept.
- Affected version(s) of this tool and your Dify version.
- Any suggested remediation, if you have one.

We aim to acknowledge reports on a best-effort basis and will coordinate a fix
and a disclosure timeline with you.

## Scope & threat model

`dify-custom-rbac` adds an authorization check that restricts Dify **log
endpoints** (workflow logs and conversation logs) to Owner/Admin roles. Keep the
following in mind:

- **Defense in depth, not a replacement for Dify's own security.** This tool
  hardens specific endpoints. It does not audit or secure the rest of your Dify
  deployment.
- **Runtime patching.** Some modes patch files inside running containers and
  restart them. Review the changes and keep backups — the tool creates timestamped
  backups automatically and supports `--rollback`.
- **Pin your images.** The provided Dockerfiles build `FROM langgenius/dify-*:latest`.
  For reproducible, auditable deployments, pin a specific Dify version.

## Running scripts safely

It can be tempting to install a tool via a `curl ... | bash` one-liner. Because
this is a security-sensitive tool, we recommend you instead **download, read, and
verify** the script before executing it (as the README's install steps do):

```bash
curl -L https://raw.githubusercontent.com/hiroppelx/dify-custom-rbac/main/apply-dify-rbac.sh -o apply-dify-rbac.sh
less apply-dify-rbac.sh        # review what it does
chmod +x apply-dify-rbac.sh
./apply-dify-rbac.sh --interactive
```

## Secret hygiene

- Never commit `.env`, credentials, tokens, or backup directories (see
  [`.gitignore`](.gitignore)).
- CI runs [`gitleaks`](https://github.com/gitleaks/gitleaks) on every push and
  pull request to catch accidentally committed secrets.
