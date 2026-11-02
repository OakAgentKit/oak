# Deployments

**0.2.0 live** on Robinhood Chain mainnet (chain ID **4663**), recorded 2026-11-02.
The [mainnet deployment record](4663.json) contains addresses and transaction hashes.
The [testnet record](46630.json) remains a placeholder; it is not mainnet configuration.
Verify chain ID, contract code and current state before use.

| Contract | Address | Deployment transaction |
| --- | --- | --- |
| OAK token | `0x6511c233790Ec10f7d673c64DC82C3F941D57828` | `0xa4523ace3b9001ea9caad3158cb6e3b4b5537f8c76f01974885f218752a2be58` |
| OakOracle | `0x9d3Ae2a760B6266F8A92240a59e5006D1AADBD30` | `0x54ed60ff36f1b83e6f6a0f41e6dbd2e0915d79a0af4bc510cfb291918d9f31b1` |
| OakBurner | `0x0704AE41934EE9b71A85cBd308786CfE503108f4` | `0xec83b462a4baffdb7c64940f9e2edaff3edaa9c5ab9493a4ecc020140e81da06` |
| OakSubscription | `0x5e0d93D4bad53388839Ac5A53dB716b70d8606A8` | `0xfc356ad47cdce9a9961d53f1d37a384c9553ab4fe60591d7e2d30df3f08a96d7` |
| OakTeamVesting | `0xbDB50e1aB95516D4f1CfCbB8eE704dc1e65f9b91` | `0x4efe37182a53179f21452960a438fe7fd59b4c6d05220efb50589be3fdbed1eb` |

The Pons curve is `0x47C76144294B009C12b8BC7C1D40CD8d65Dd486e`.
The existing ETH/USDG pool is `0x52e65B17fB6E5BA00Ed806f37Afcd2DaA50271Ca`.
Its reference transaction in the JSON is the oracle deployment that reads it, not pool creation.

## Team vesting

[OakTeamVesting](../src/OakTeamVesting.sol) holds the launch-wallet allocation funded by
transaction `0xf923681d37dc59c26214ba4f3552a25ff5f96088d73a52e03c5ed5d7e87ebf4a`:
**29,989,491.552825155605852396 OAK** (18 decimals;
`29989491552825155605852396` base units at funding).
This is a funding record, not a promise of the current balance.

Vesting starts **2027-02-01 00:00 UTC**, runs linearly for **365 days**
(`31536000` seconds), and ends **2028-02-01 00:00 UTC**. The additional cliff is zero.
The beneficiary at deployment is the launch wallet
`0x84b1B9e5D1cAfD9543E684BB39E9cbD478189EE2`.
Anyone can release vested funds to the current beneficiary. The beneficiary can
transfer ownership without accelerating the schedule. The deployer has no separate
withdrawal or emergency-sweep role. Tokens added later follow the original schedule.
See the [vesting tests](../test/OakTeamVesting.t.sol) and [custody disclosures](../../docs/security.md).

## Paid access

The published core and add-on packages are **0.2.0**. Hosted actions use paid mode:
verified ERC-8004 identity and an active subscription are required; reads stay available.
Launch phase still controls plan availability; read `account` before subscribing.
Payments split 25% to the burner and 75% to the single-owner treasury.
The treasury/admin is `0x856bb126188bDB5e425D3ac9D59E9ffBD12e6ECf`.
There is no second-signature requirement. See [access and pricing](../../docs/access-and-pricing.md).
