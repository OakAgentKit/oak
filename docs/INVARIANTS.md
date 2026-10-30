# Contract Invariants

- Every subscription payment is conserved: 25% (`amount / 4`) goes to the burner and 75% (the remainder) goes to treasury ([holder split test](../contracts/test/OakSubscription.t.sol#L314), [odd no-hold split test](../contracts/test/OakSubscription.t.sol#L1397), [renewal split test](../contracts/test/OakSubscription.t.sol#L1407)).
- No successful subscription or renewal settlement leaves USDG in `OakSubscription` ([settlement balance test](../contracts/test/OakSubscription.t.sol#L825)).
- Paid time advances from `max(block.timestamp, paidUntil)` and never exceeds 90 days ahead ([monotonic extension test](../contracts/test/OakSubscription.t.sol#L661), [prepay-cap test](../contracts/test/OakSubscription.t.sol#L670)).
- Each burner price-note nonce is single-use for its caller ([burner nonce test](../contracts/test/OakBurner.t.sol#L493)).
- A stuck-fund sweep transfers no more than the balance recorded when armed; later deposits remain for a new timer ([armed-balance test](../contracts/test/OakBurner.t.sol#L691), [post-arm deposit fuzz test](../contracts/test/OakBurner.t.sol#L727)).
