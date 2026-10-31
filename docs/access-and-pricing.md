# Access and pricing

Hosted actions are limited to the Oak team until the token and subscription launch.
Strangers can discover tools and call reads such as `find_token`; private-mode
actions require a server-allowlisted wallet.
Installing the published npm packages is free under their [own license](../LICENSE-PACKAGES.md).
These are launch subscription terms, not a statement that subscriptions are open today.

## Launch phases

- **Curve:** only no-hold opens, at 12.333333 USDG per 30 days; holder stays closed.
- **Warmup:** after Pons graduation, both plans wait for 30 minutes of pool history.
- **Ready:** holder opens; no-hold follows the current entry-price calculation at each renewal.

Read `account` for phase and indicative price. Read tools require neither identity
nor subscription in normal service mode. Actions require both a verified ERC-8004
identity and an active subscription. Public identity registration needs authorization,
publishes the profile and costs ETH gas. Linking an existing identity is gasless;
an external owner signs the link in their own terminal.

## Plans

**Holder: 9 USDG per 30 days.** Joining requires holding the quoted entry count `N`
of OAK. The sign-up transaction burns `ceil(N * 5 / 100)` and records the remainder
as `signupOakCount`. Hold 20,000 OAK: 1,000 burns and 19,000 is tracked.
Keep at least the tracked amount for action access. Renewals need no price note
and burn nothing. Holding OAK buys access and nothing else.

**No-hold: 9 USDG plus one sixth of the entry price per 30 days.** At the $20 entry
floor this is 12.333333 USDG. After warmup it is repriced at each renewal.
The entry price uses total supply times OAK USD price, treating USDG as $1:
under $100k gives $20; $100k–$500k gives $20→$75; $500k–$1M gives $75→$100;
$1M–$10M gives $100→$300; above $10M gives $300. These are subscription
calculation bands, not forecasts. The service issues a 30-minute OAK price note
with a 5-minute life. Contracts check it against on-chain ETH/USDG pricing and
a 50% live-pool guard; see the exact [checks and limits](security.md).

## Payments, renewal and cancellation

- Each payment splits in the same transaction: 25% to `OakBurner`, 75% to the single-owner treasury.
- Prepayment is capped at 90 days ahead. Oak adds no per-call or trade fee; ETH gas and project fees are separate.
- `oak mcp` checks on startup and hourly; a plan with 3 days or less remaining can renew using local USDG and ETH.
- Since **0.1.1**, new renewal signatures require human confirmation by default. Unattended renewal requires the owner's explicit auto setting.
- `oak renew` reconciles pending payments and renews when due. Missing funds or an unresolved journal pause actions.
- `oak cancel` ends access immediately and forfeits remaining paid days. Cancel before switching plans.
- An authoritative grandfathered holder on a retired contract uses `oak renew` when due to migrate with carried paid time, its recorded post-burn count and zero burn.

Contract deployments remain [launch placeholders](../contracts/deployments/README.md).
Do not fund an address taken from a placeholder. Use the verified deployment for
your selected network and inspect the payment preview and confirmation.
