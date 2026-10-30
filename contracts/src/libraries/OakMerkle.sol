// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @notice Source-bound, double-hashed grandfather leaves with sorted-pair proofs.
library OakMerkle {
    bytes32 internal constant LEAF_GRANDFATHER = keccak256("OakGrandfather/v1");

    function grandfatherLeaf(address wallet, uint256 count, address source) internal pure returns (bytes32) {
        bytes32 inner = keccak256(abi.encode(LEAF_GRANDFATHER, wallet, count, source));
        return keccak256(bytes.concat(inner));
    }

    function verify(bytes32 root, bytes32 leaf, bytes32[] memory proof) internal pure returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }
}
