// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PriceNote} from "../libraries/OakPriceNote.sol";

interface IOakBurner {
    /// @notice Burn at most min(0.5% of oracle liquidity, 250 USDG) through the fixed two-leg route.
    /// @dev Leg 1 allows 50 bps below the 30-minute ETH/USD average. The OAK floor uses max(note, spot)
    ///      and the larger of the USDG-derived and actual-WETH-derived outputs, adjusted for fees.
    ///      A successful burn disarms at ceil(armedBalance / 100), or on consuming armedRemaining;
    ///      smaller burns reduce only armedRemaining. The note/spot tolerance remains 10%.
    function buyAndBurn(uint256 usdgIn, PriceNote calldata n, bytes calldata sig) external;
    /// @notice Snapshot the current balance and nonzero price signer for a 90-day sweep timer (safe only).
    /// @dev Re-arming an active timer requires a previously flagged signer change and restarts the delay.
    function armSweep() external;
    /// @notice After 90 days, transfer min(current USDG balance, armedRemaining) to the safe.
    /// @dev Requires the original signer and no flagged change; clears all arming state on completion.
    function sweepStuck() external;
    function noteUsed(address wallet, bytes32 nonce) external view returns (bool);
    function armedAt() external view returns (uint64);
    /// @notice Fixed USDG snapshot at arming; never reduced by burns. Sets the rounded-up 1% threshold.
    function armedBalance() external view returns (uint256);
    /// @notice Unspent armed USDG, reduced by sub-threshold burns; excludes subsequent deposits.
    function armedRemaining() external view returns (uint256);
    /// @notice Price signer captured at arming, cleared on disarm or sweep.
    function armedSigner() external view returns (address);
    /// @notice Sticky record that someone observed a different signer while armed.
    function armedSignerChanged() external view returns (bool);
    /// @notice Anyone may flag a live signer mismatch. An unchanged signer or unarmed sweep is a no-op.
    /// @dev A toggle-back without a flag is not detected; a watcher must call during the mismatch.
    function flagSignerChange() external;
    function lastBurnAt() external view returns (uint64);
    function oakDecimals() external view returns (uint8);

    event Burned(uint256 usdgIn, uint256 oakBurned);
    event SweepArmed(uint64 at, uint256 balance);
    event SweepDisarmed(uint8 reason);
    event Swept(uint256 amount);

    error NoteUsed();
}
