# Security

## Reporting a vulnerability

Report vulnerabilities privately through [GitHub private vulnerability reporting](https://github.com/OakAgentKit/oak/security/advisories/new).
Do not open a public issue, pull request or social post for a security problem.

Include the affected surface (npm add-on or core package, contracts in [`contracts/`](contracts/),
hosted service, or deployed contracts on Robinhood Chain `4663`), reproduction steps or a Foundry test,
the commit SHA or package version, and the impact against the bounds in [THREAT_MODEL.md](THREAT_MODEL.md).

We acknowledge reports within **48 hours** and give a triage assessment within **7 days**, then coordinate
the fix and public disclosure. Good-faith research on local forks or testnet `46630` is welcome under the
safe harbor in [docs/security.md](docs/security.md#1-reporting-a-vulnerability), which is the full policy.

## Supported versions

| Version | Supported |
| --- | --- |
| 0.1.2 (latest) | Yes |
| Earlier versions | Fixes ship in the latest release; please upgrade |

The [security policy](docs/security.md) also covers local custody, confirmation and transaction checks,
and contract authority.
