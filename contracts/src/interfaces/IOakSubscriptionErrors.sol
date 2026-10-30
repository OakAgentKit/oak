// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev Solidity shares event and error identifiers in one interface scope. Keeping the frozen
///      Retired() error in this companion preserves its selector alongside Retired(uint64).
interface IOakSubscriptionErrors {
    error Retired();
}
