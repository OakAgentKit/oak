// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Hashes} from "@openzeppelin/contracts/utils/cryptography/Hashes.sol";
import {OakMerkle} from "../src/libraries/OakMerkle.sol";

contract OakMerkleTest is Test {
    using stdJson for string;

    string internal vectors;

    function setUp() public {
        vectors = vm.readFile("test/vectors.json");
    }

    function test_GrandfatherLeafVectors() public view {
        assertEq(OakMerkle.LEAF_GRANDFATHER, vectors.readBytes32(".grandfather.leafTag"));
        bytes32 root = vectors.readBytes32(".grandfather.root");
        for (uint256 i; i < 2; ++i) {
            string memory base = string.concat(".grandfather.entries[", vm.toString(i), "]");
            bytes32 leaf = OakMerkle.grandfatherLeaf(
                vectors.readAddress(string.concat(base, ".wallet")),
                _u(string.concat(base, ".count")),
                vectors.readAddress(string.concat(base, ".source"))
            );
            assertEq(leaf, vectors.readBytes32(string.concat(base, ".leaf")));
            assertTrue(OakMerkle.verify(root, leaf, vectors.readBytes32Array(string.concat(base, ".proof"))));
        }
    }

    function test_WrongLeafRejected() public view {
        bytes32 root = vectors.readBytes32(".grandfather.root");
        address wallet = vectors.readAddress(".grandfather.entries[0].wallet");
        uint256 count = _u(".grandfather.entries[0].count");
        address source = vectors.readAddress(".grandfather.entries[0].source");
        bytes32[] memory proof = vectors.readBytes32Array(".grandfather.entries[0].proof");
        assertFalse(OakMerkle.verify(root, OakMerkle.grandfatherLeaf(wallet, count + 1, source), proof));
        assertFalse(
            OakMerkle.verify(
                root, OakMerkle.grandfatherLeaf(wallet, count, vectors.readAddress(".grandfather.foreignSource")), proof
            )
        );
        assertFalse(OakMerkle.verify(root, OakMerkle.grandfatherLeaf(address(0xBEEF), count, source), proof));
    }

    function test_CanonicalGrandfatherExportByteStable() public view {
        bytes memory canonical = bytes(vectors.readString(".grandfather.canonicalJson"));
        assertEq(sha256(canonical), vectors.readBytes32(".grandfather.canonicalJsonSha256"));
        assertTrue(canonical.length > 0);
        assertNotEq(canonical[canonical.length - 1], bytes1("\n"));
    }

    function testFuzz_SortedPairProofIsOrderIndependent(bytes32 first, bytes32 second) public pure {
        bytes32 root = Hashes.commutativeKeccak256(first, second);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = second;
        assertTrue(OakMerkle.verify(root, first, proof));
        proof[0] = first;
        assertTrue(OakMerkle.verify(root, second, proof));
    }

    function _u(string memory path) internal view returns (uint256) {
        return vm.parseUint(vectors.readString(path));
    }
}
