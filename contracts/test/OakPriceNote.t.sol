// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PriceNote, OakPriceNote} from "../src/libraries/OakPriceNote.sol";
import {IOakOracle} from "../src/interfaces/IOakOracle.sol";
import {MockOracle} from "./mocks/MockOracle.sol";

contract OakPriceNoteTest is Test {
    using stdJson for string;

    uint256 internal constant TEST_PRIVATE_KEY = 0xA11CE;
    address internal constant ETH_SOURCE = address(0xE701);
    address internal constant SPOT_SOURCE = address(0x5707);
    bytes32 internal constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant NAME_HASH = keccak256("OakPriceNote");
    bytes32 internal constant VERSION_HASH = keccak256("1");

    string internal vectors;
    MockOracle internal oracle;

    function setUp() public {
        vectors = vm.readFile("test/vectors.json");
        vm.chainId(4663);
        oracle = new MockOracle(ETH_SOURCE, SPOT_SOURCE);
        oracle.setPhase(1);
        oracle.setEthUsdE18(_u(".oracle.ethUsd.ethUsdE18"));
        oracle.setSpotOakPerEthE18(_u(".priceNote.oakPerEthE18") * 2);
        oracle.setPriceSigner(vm.addr(TEST_PRIVATE_KEY));
    }

    function test_NoteDigestMatchesVector() public view {
        PriceNote memory note = _vectorNote();
        address consumer = vectors.readAddress(".priceNote.consumer");
        bytes32 domain = _domainSeparator(consumer, 4663, VERSION_HASH);
        bytes32 structHash =
            keccak256(abi.encode(OakPriceNote.TYPEHASH, note.wallet, note.oakPerEthE18, note.timestamp, note.nonce));
        assertEq(OakPriceNote.TYPEHASH, vectors.readBytes32(".priceNote.typehash"));
        assertEq(domain, vectors.readBytes32(".priceNote.domainSeparator"));
        assertEq(structHash, vectors.readBytes32(".priceNote.structHash"));
        assertEq(OakPriceNote.digest(note, consumer), vectors.readBytes32(".priceNote.digest"));
        assertEq(
            OakPriceNote.recover(note, vectors.readBytes(".priceNote.signature"), consumer),
            vectors.readAddress(".priceNote.signer")
        );
    }

    function test_NoteExpiryWindow() public {
        uint64 now_ = 2_000_000_000;
        vm.warp(now_);
        address consumer = vectors.readAddress(".priceNote.consumer");
        address wallet = vectors.readAddress(".priceNote.wallet");

        for (uint256 i; i < 4; ++i) {
            int256 offset = _i(string.concat(".priceNote.expiryOffsets[", vm.toString(i), "]"));
            PriceNote memory note = PriceNote(
                wallet,
                _u(".priceNote.oakPerEthE18"),
                uint64(uint256(int256(uint256(now_)) + offset)),
                keccak256(abi.encode(i))
            );
            bytes memory signature = _sign(note, consumer, TEST_PRIVATE_KEY);
            vm.prank(consumer);
            if (offset == 1) {
                vm.expectRevert(IOakOracle.NoteNotYetValid.selector);
                oracle.verifyNote(note, signature, wallet);
            } else if (offset == -301) {
                vm.expectRevert(IOakOracle.NoteExpired.selector);
                oracle.verifyNote(note, signature, wallet);
            } else {
                assertEq(oracle.verifyNote(note, signature, wallet), note.oakPerEthE18);
            }
        }
    }

    function test_NoteWrongWalletRejected() public {
        vm.warp(_u(".priceNote.timestamp"));
        PriceNote memory note = _vectorNote();
        address consumer = vectors.readAddress(".priceNote.consumer");
        vm.prank(consumer);
        vm.expectRevert(IOakOracle.NoteWrongWallet.selector);
        oracle.verifyNote(note, vectors.readBytes(".priceNote.signature"), address(0xBAD));
    }

    function test_NoteWrongConsumerRejected() public {
        vm.warp(_u(".priceNote.timestamp"));
        PriceNote memory note = _vectorNote();
        vm.prank(vectors.readAddress(".priceNote.wrongConsumer"));
        vm.expectRevert(IOakOracle.NoteBadSignature.selector);
        oracle.verifyNote(note, vectors.readBytes(".priceNote.signature"), note.wallet);
    }

    function test_NoteWrongChainRejected() public {
        vm.warp(_u(".priceNote.timestamp"));
        PriceNote memory note = _vectorNote();
        address consumer = vectors.readAddress(".priceNote.consumer");
        bytes32 wrongDigest = _digest(note, consumer, _u(".priceNote.wrongChainId"), VERSION_HASH);
        bytes memory wrongSignature = _signDigest(wrongDigest, TEST_PRIVATE_KEY);
        vm.prank(consumer);
        vm.expectRevert(IOakOracle.NoteBadSignature.selector);
        oracle.verifyNote(note, wrongSignature, note.wallet);
    }

    function test_NoteWrongVersionRejected() public {
        vm.warp(_u(".priceNote.timestamp"));
        PriceNote memory note = _vectorNote();
        address consumer = vectors.readAddress(".priceNote.consumer");
        bytes32 wrongDigest =
            _digest(note, consumer, block.chainid, keccak256(bytes(vectors.readString(".priceNote.wrongVersion"))));
        bytes memory wrongSignature = _signDigest(wrongDigest, TEST_PRIVATE_KEY);
        vm.prank(consumer);
        vm.expectRevert(IOakOracle.NoteBadSignature.selector);
        oracle.verifyNote(note, wrongSignature, note.wallet);
    }

    function test_MalformedSignatureRejected() public {
        vm.warp(_u(".priceNote.timestamp"));
        PriceNote memory note = _vectorNote();
        address consumer = vectors.readAddress(".priceNote.consumer");
        vm.prank(consumer);
        vm.expectRevert(IOakOracle.NoteBadSignature.selector);
        oracle.verifyNote(note, hex"deadbeef", note.wallet);
    }

    function test_GuardEndpointVectors() public {
        uint64 now_ = 2_000_000_000;
        vm.warp(now_);
        address consumer = vectors.readAddress(".priceNote.consumer");
        address wallet = vectors.readAddress(".priceNote.wallet");

        _assertGuardVector(".guard", now_, consumer, wallet);
        _assertGuardVector(".guard.oddSpot", now_, consumer, wallet);
    }

    function testFuzz_GuardUsesInclusiveIntegerBand(uint128 spotRaw) public {
        uint256 spot = bound(uint256(spotRaw), 1, type(uint128).max);
        uint64 now_ = 2_000_000_000;
        vm.warp(now_);
        oracle.setSpotOakPerEthE18(spot);
        address consumer = vectors.readAddress(".priceNote.consumer");
        address wallet = vectors.readAddress(".priceNote.wallet");
        uint256 lower = spot / 2 + spot % 2;
        uint256 upper = spot + spot / 2;

        _assertGuardValue(lower, true, now_, consumer, wallet);
        _assertGuardValue(upper, true, now_, consumer, wallet);
        _assertGuardValue(lower - 1, false, now_, consumer, wallet);
        _assertGuardValue(upper + 1, false, now_, consumer, wallet);
    }

    function test_GuardArithmeticOverflowReverts() public {
        uint64 now_ = 2_000_000_000;
        vm.warp(now_);
        uint256 spot = type(uint256).max / 3 + 1;
        oracle.setSpotOakPerEthE18(spot);
        address consumer = vectors.readAddress(".priceNote.consumer");
        address wallet = vectors.readAddress(".priceNote.wallet");
        PriceNote memory note = PriceNote(wallet, spot, now_, keccak256("overflow-control"));
        bytes memory signature = _sign(note, consumer, TEST_PRIVATE_KEY);

        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        vm.prank(consumer);
        oracle.verifyNote(note, signature, wallet);
    }

    function test_OracleUnreadablePerSourceVectors() public {
        assertEq(vectors.readBytes(".oracle.unreadable.old")[0], bytes1(0x08));
        assertEq(vectors.readBytes(".oracle.unreadable.uninitialized")[0], bytes1(0x08));
        assertTrue(vectors.readBool(".oracle.unreadable.eoaSuccess"));
        assertEq(vectors.readBytes(".oracle.unreadable.eoaReturn").length, 0);
        assertEq(bytes4(vectors.readBytes(".oracle.unreadable.facetNotFound")), bytes4(0x800ab12c));

        oracle.setSourceUnreadable(ETH_SOURCE, true);
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, ETH_SOURCE));
        oracle.ethUsdE18();
        oracle.setSourceUnreadable(ETH_SOURCE, false);

        oracle.setSourceUnreadable(SPOT_SOURCE, true);
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, SPOT_SOURCE));
        oracle.spotOakPerEthE18();
    }

    function test_UsdGDomainVectorAndAlteredFieldControl() public view {
        bytes32 actual = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(vectors.readString(".usdgDomain.name"))),
                keccak256(bytes(vectors.readString(".usdgDomain.version"))),
                _u(".usdgDomain.chainId"),
                vectors.readAddress(".usdgDomain.verifyingContract")
            )
        );
        bytes32 wrong = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(vectors.readString(".usdgDomain.name"))),
                keccak256(bytes(vectors.readString(".usdgDomain.version"))),
                _u(".usdgDomain.wrongChainId"),
                vectors.readAddress(".usdgDomain.verifyingContract")
            )
        );
        assertEq(actual, vectors.readBytes32(".usdgDomain.domainSeparator"));
        assertEq(wrong, vectors.readBytes32(".usdgDomain.wrongChainDomainSeparator"));
        assertNotEq(actual, wrong);
    }

    function testFuzz_NoteDigestBindsConsumer(address first, address second) public view {
        vm.assume(first != second);
        PriceNote memory note = _vectorNote();
        assertNotEq(OakPriceNote.digest(note, first), OakPriceNote.digest(note, second));
    }

    function _assertGuardVector(string memory base, uint64 timestamp, address consumer, address wallet) internal {
        oracle.setSpotOakPerEthE18(_u(string.concat(base, ".spotOakPerEthE18")));
        _assertGuardAccepted(string.concat(base, ".lowerAccepted"), timestamp, consumer, wallet);
        _assertGuardAccepted(string.concat(base, ".upperAccepted"), timestamp, consumer, wallet);
        _assertGuardRejected(string.concat(base, ".lowerRejected"), timestamp, consumer, wallet);
        _assertGuardRejected(string.concat(base, ".upperRejected"), timestamp, consumer, wallet);
    }

    function _assertGuardAccepted(string memory path, uint64 timestamp, address consumer, address wallet) internal {
        PriceNote memory note = PriceNote(wallet, _u(path), timestamp, keccak256(bytes(path)));
        bytes memory signature = _sign(note, consumer, TEST_PRIVATE_KEY);
        vm.prank(consumer);
        assertEq(oracle.verifyNote(note, signature, wallet), note.oakPerEthE18);
    }

    function _assertGuardRejected(string memory path, uint64 timestamp, address consumer, address wallet) internal {
        PriceNote memory note = PriceNote(wallet, _u(path), timestamp, keccak256(bytes(path)));
        bytes memory signature = _sign(note, consumer, TEST_PRIVATE_KEY);
        uint256 spot = oracle.spotOakPerEthE18();
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.NoteOutsideGuard.selector, spot, note.oakPerEthE18));
        vm.prank(consumer);
        oracle.verifyNote(note, signature, wallet);
    }

    function _assertGuardValue(uint256 value, bool accepted, uint64 timestamp, address consumer, address wallet)
        internal
    {
        PriceNote memory note = PriceNote(wallet, value, timestamp, keccak256(abi.encode(value, accepted)));
        bytes memory signature = _sign(note, consumer, TEST_PRIVATE_KEY);
        uint256 spot = oracle.spotOakPerEthE18();
        bool insideGuard = note.oakPerEthE18 * 2 >= spot && note.oakPerEthE18 * 2 <= spot * 3;
        assertEq(insideGuard, accepted);
        if (!accepted) {
            vm.expectRevert(abi.encodeWithSelector(IOakOracle.NoteOutsideGuard.selector, spot, note.oakPerEthE18));
        }
        vm.prank(consumer);
        oracle.verifyNote(note, signature, wallet);
    }

    function _vectorNote() internal view returns (PriceNote memory) {
        return PriceNote(
            vectors.readAddress(".priceNote.wallet"),
            _u(".priceNote.oakPerEthE18"),
            uint64(_u(".priceNote.timestamp")),
            vectors.readBytes32(".priceNote.nonce")
        );
    }

    function _sign(PriceNote memory note, address consumer, uint256 key) internal view returns (bytes memory) {
        return _signDigest(OakPriceNote.digest(note, consumer), key);
    }

    function _signDigest(bytes32 digest_, uint256 key) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest_);
        return abi.encodePacked(r, s, v);
    }

    function _digest(PriceNote memory note, address consumer, uint256 chainId, bytes32 versionHash)
        internal
        pure
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(OakPriceNote.TYPEHASH, note.wallet, note.oakPerEthE18, note.timestamp, note.nonce)
        );
        return MessageHashUtils.toTypedDataHash(_domainSeparator(consumer, chainId, versionHash), structHash);
    }

    function _domainSeparator(address consumer, uint256 chainId, bytes32 versionHash) internal pure returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, versionHash, chainId, consumer));
    }

    function _u(string memory path) internal view returns (uint256) {
        return vm.parseUint(vectors.readString(path));
    }

    function _i(string memory path) internal view returns (int256) {
        return vm.parseInt(vectors.readString(path));
    }
}
