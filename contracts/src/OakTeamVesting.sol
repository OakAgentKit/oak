// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {VestingWalletCliff} from "@openzeppelin/contracts/finance/VestingWalletCliff.sol";

/// @notice Unmodified OpenZeppelin vesting: accrual starts at startTimestamp,
/// becomes releasable at startTimestamp + cliffSeconds, and ends at start + duration.
/// @dev The beneficiary is the transferable Ownable owner. No deployer withdrawal role.
contract OakTeamVesting is VestingWalletCliff {
    constructor(address beneficiary, uint64 startTimestamp, uint64 durationSeconds, uint64 cliffSeconds)
        VestingWallet(beneficiary, startTimestamp, durationSeconds)
        VestingWalletCliff(cliffSeconds)
    {}
}
