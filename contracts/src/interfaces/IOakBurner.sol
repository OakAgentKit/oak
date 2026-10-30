// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PriceNote} from "../libraries/OakPriceNote.sol";

interface IOakBurner {
    function buyAndBurn(uint256 usdgIn, PriceNote calldata n, bytes calldata sig) external;
    function armSweep() external;
    function sweepStuck() external;
    function noteUsed(address wallet, bytes32 nonce) external view returns (bool);
    function armedAt() external view returns (uint64);
    function armedBalance() external view returns (uint256);
    function lastBurnAt() external view returns (uint64);
    function oakDecimals() external view returns (uint8);

    event Burned(uint256 usdgIn, uint256 oakBurned);
    event SweepArmed(uint64 at, uint256 balance);
    event SweepDisarmed(uint8 reason);
    event Swept(uint256 amount);

    error NoteUsed();
}
