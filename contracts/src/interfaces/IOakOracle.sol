// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PriceNote} from "../libraries/OakPriceNote.sol";

interface IOakOracle {
    function syncPhase() external returns (uint8);
    function phase() external view returns (uint8);
    function available() external view returns (bool);
    function ethUsdE18() external view returns (uint256);
    function spotOakPerEthE18() external view returns (uint256);
    function verifyNote(PriceNote calldata n, bytes calldata sig, address boundWallet)
        external
        view
        returns (uint256 oakPerEthE18);
    function liquidityUsdgE6() external view returns (uint256);
    function supplyNet() external view returns (uint256);
    function priceSigner() external view returns (address);
    function setPriceSigner(address signer) external;

    event PriceSignerSet(address signer);

    error NotReady();
    error OracleUnreadable(address source);
    error NoteWrongWallet();
    error NoteNotYetValid();
    error NoteExpired();
    error NoteBadSignature();
    error NoteOutsideGuard(uint256 spot, uint256 note);
}
