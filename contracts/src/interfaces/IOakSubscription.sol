// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PriceNote} from "../libraries/OakPriceNote.sol";

interface IOakSubscription {
    function subscribe(uint8 plan, uint256 maxCount, uint256 maxPrice, PriceNote calldata n, bytes calldata sig)
        external;
    function subscribeWithAuthorization(
        uint256 maxCount,
        PriceNote calldata n,
        bytes calldata sig,
        bytes calldata usdgAuth
    ) external;
    function subscribeGrandfathered(uint256 count, bytes32[] calldata proof) external;
    function subscribeGrandfatheredWithAuthorization(uint256 count, bytes32[] calldata proof, bytes calldata usdgAuth)
        external;
    function renew() external;
    function renewWithAuthorization(bytes calldata usdgAuth) external;
    function renewNoHold(uint256 maxPrice, PriceNote calldata n, bytes calldata sig) external;
    function cancel() external;
    function retire() external;
    function setGrandfatherRoot(bytes32 root, uint64 deadline) external;
    function setPayees(address burner, address treasury) external;
    function sweepToTreasury() external;
    function plan(address wallet) external view returns (uint8);
    function paidUntil(address wallet) external view returns (uint64);
    function signupOakCount(address wallet) external view returns (uint256);
    function expiresAt(address wallet) external view returns (uint64);
    function hasRecord(address wallet) external view returns (bool);
    function hasAccess(address wallet) external view returns (bool);
    function holderOpen() external view returns (bool);
    function quoteHolder(PriceNote calldata n, bytes calldata sig) external view returns (uint256 count, uint256 burn);
    function quoteNoHold(PriceNote calldata n, bytes calldata sig) external view returns (uint256 price);
    function noteUsed(address wallet, bytes32 nonce) external view returns (bool);
    function retired() external view returns (bool);
    function previous() external view returns (address);
    function grandfathered(address wallet) external view returns (bool);

    event Subscribed(
        address indexed wallet,
        uint8 plan,
        uint64 paidUntil,
        uint256 signupOakCount,
        uint256 oakBurned,
        bool grandfathered
    );
    event Renewed(address indexed wallet, uint8 plan, uint64 paidUntil, uint256 amountPaid);
    event Cancelled(address indexed wallet, uint64 at);
    event Retired(uint64 at);
    event GrandfatherRootSet(bytes32 root, uint64 deadline);

    error HolderClosed();
    error NoteUsed();
}
