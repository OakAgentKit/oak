// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

struct PriceNote {
    address wallet;
    uint256 oakPerEthE18;
    uint64 timestamp;
    bytes32 nonce;
}

/// @notice EIP-712 hashing and recovery for consumer-bound Oak price notes.
library OakPriceNote {
    bytes32 internal constant TYPEHASH =
        keccak256("PriceNote(address wallet,uint256 oakPerEthE18,uint64 timestamp,bytes32 nonce)");
    uint64 internal constant NOTE_TTL = 300;

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant NAME_HASH = keccak256("OakPriceNote");
    bytes32 private constant VERSION_HASH = keccak256("1");

    function digest(PriceNote memory n, address consumer) internal view returns (bytes32) {
        bytes32 domainSeparator =
            keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, consumer));
        bytes32 structHash = keccak256(abi.encode(TYPEHASH, n.wallet, n.oakPerEthE18, n.timestamp, n.nonce));
        return MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
    }

    function recover(PriceNote memory n, bytes memory sig, address consumer) internal view returns (address) {
        (address signer, ECDSA.RecoverError error,) = ECDSA.tryRecover(digest(n, consumer), sig);
        return error == ECDSA.RecoverError.NoError ? signer : address(0);
    }
}
