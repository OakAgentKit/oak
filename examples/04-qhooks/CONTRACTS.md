# Contract read-recipe evidence

Public RH RPC readback, 2026-11-16 at block `0x6e94b73` (same-block hash checked after the reads):

| Contract | EIP-55 address | Runtime keccak256 | Fee observed |
| --- | --- | --- | --- |
| QOtcEscrow | `0xBea24499f82f1e018A4DFF5607b7c54141cBfbF8` | `0x9fb3b5a21b44bc07fbc7fae6063d901504323e93c443d84f361ec56268ee5ca5` | default 100 bps |
| QAgreements | `0x9B6E579dD876c364bf232D2958d7CC45937809bf` | `0x116c9cd1f96b4016a518bbd6b61b9b64c93ec0c952532c612c497bb6e4ddb9fb` | 50 bps |

Both `feeRecipient()` reads returned RH fee Safe `0x2b1cf7c4071a98a59709166dfa73c7acb7e83e71`. These are deployed configuration reads at that block; the escrow default is not a quote of every deal's selectable fee. The current QHooks runtime hashes and deployed ABI match the reader pins. `defaultFeeBps()` returns `uint16` on QOtcEscrow; `feeBps()` returns `uint256` on QAgreements. Addresses were EIP-55 checksummed with Foundry `cast to-check-sum-address`.

Only `eth_chainId`, `eth_getBlockByNumber`, `eth_getCode`, and four `eth_call` view reads were requested: two logical RPC batches / nine logical items. The existing public transport observed two recoveries through public Pinax; no Alchemy, keys, approvals, signatures or transactions. Re-read code/configuration before enabling a future executable module. No deployed address is used in the synthetic trade-plan fixtures.

The recipes intentionally contain only four simple `view` functions supported by the public declarative ABI format. Dynamic HTTP QProof/discovery and guarded launch/trade plans do not fit a one-contract ABI recipe and are supplied by the separate example module. Their execution is not claimed.
