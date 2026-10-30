// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PriceNote, OakPriceNote} from "../../src/libraries/OakPriceNote.sol";
import {IOakOracle} from "../../src/interfaces/IOakOracle.sol";

contract MockOracle is IOakOracle {
    address public immutable ethUsdSource;
    address public immutable spotSource;

    uint8 private _phase;
    uint256 private _ethUsdE18;
    uint256 private _spotOakPerEthE18;
    uint256 private _liquidityUsdgE6;
    uint256 private _supplyNet;
    address private _priceSigner;
    mapping(address source => bool unreadable) public sourceUnreadable;

    constructor(address ethUsdSource_, address spotSource_) {
        ethUsdSource = ethUsdSource_;
        spotSource = spotSource_;
    }

    function syncPhase() external view returns (uint8) {
        return _phase;
    }

    function phase() external view returns (uint8) {
        return _phase;
    }

    function available() external view returns (bool) {
        return _phase == 1;
    }

    function ethUsdE18() external view returns (uint256) {
        if (sourceUnreadable[ethUsdSource] || _ethUsdE18 == 0) revert OracleUnreadable(ethUsdSource);
        return _ethUsdE18;
    }

    function spotOakPerEthE18() public view returns (uint256) {
        if (_phase != 1) revert NotReady();
        if (sourceUnreadable[spotSource] || _spotOakPerEthE18 == 0) revert OracleUnreadable(spotSource);
        return _spotOakPerEthE18;
    }

    function verifyNote(PriceNote calldata note, bytes calldata signature, address boundWallet)
        external
        view
        returns (uint256 oakPerEthE18)
    {
        if (note.wallet != boundWallet) revert NoteWrongWallet();
        if (note.timestamp > block.timestamp) revert NoteNotYetValid();
        if (block.timestamp - note.timestamp > OakPriceNote.NOTE_TTL) revert NoteExpired();
        address signer = OakPriceNote.recover(note, signature, msg.sender);
        if (_priceSigner == address(0) || signer != _priceSigner) revert NoteBadSignature();

        uint256 spot = spotOakPerEthE18();
        bool insideGuard = note.oakPerEthE18 * 2 >= spot && note.oakPerEthE18 * 2 <= spot * 3;
        if (!insideGuard) revert NoteOutsideGuard(spot, note.oakPerEthE18);
        return note.oakPerEthE18;
    }

    function liquidityUsdgE6() external view returns (uint256) {
        return _liquidityUsdgE6;
    }

    function supplyNet() external view returns (uint256) {
        return _supplyNet;
    }

    function priceSigner() external view returns (address) {
        return _priceSigner;
    }

    function setPriceSigner(address signer) external {
        _priceSigner = signer;
        emit PriceSignerSet(signer);
    }

    function setPhase(uint8 phase_) external {
        _phase = phase_;
    }

    function setEthUsdE18(uint256 value) external {
        _ethUsdE18 = value;
    }

    function setSpotOakPerEthE18(uint256 value) external {
        _spotOakPerEthE18 = value;
    }

    function setLiquidityUsdgE6(uint256 value) external {
        _liquidityUsdgE6 = value;
    }

    function setSupplyNet(uint256 value) external {
        _supplyNet = value;
    }

    function setSourceUnreadable(address source, bool unreadable) external {
        sourceUnreadable[source] = unreadable;
    }
}
