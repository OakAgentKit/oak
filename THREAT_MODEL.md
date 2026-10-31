# Threat model

Oak's threat model is published in the security documentation, so it has one home.
Use these sections when describing the impact of a report:

- **Custody:** [Where your key lives](docs/security.md#2-where-your-key-lives-local-self-custody): the wallet is created and used on the user's machine; the hosted service never receives it.
- **Authority:** [Keys and authority matrix](docs/security.md#4-keys-and-authority-matrix): what each key can and cannot do, including the single owner key and the sign-only price signer.
- **Burner bounds:** [Burner 90-day armed sweep rule](docs/security.md#5-burner-90-day-armed-sweep-rule) and [exact on-chain burner checks](docs/security.md#6-exact-on-chain-burner-checks).
- **Contract invariants:** [docs/INVARIANTS.md](docs/INVARIANTS.md), with Foundry tests in [contracts/test](contracts/test/).
- **Transaction checks and limits:** [Before anything signs](README.md#before-anything-signs) lists the local checks, the confirmation step and what they do not prove.

Report a vulnerability privately as described in [SECURITY.md](SECURITY.md).
