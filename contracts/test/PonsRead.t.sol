// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {IPons, IPonsFactoryView, IPonsHookView, PonsRead} from "../src/interfaces/IPons.sol";

contract EmptyPonsReadTarget {}

contract PonsReadHarness {
    function launchRecordSummary(address factory, address token)
        external
        view
        returns (
            bool readable,
            address actualToken,
            address pairToken,
            uint24 poolFee,
            int24 tickSpacing,
            uint16 creatorTaxBps,
            bool exists
        )
    {
        return PonsRead.launchRecordSummary(factory, token);
    }

    function memeHook(address factory) external view returns (bool readable, address hook) {
        return PonsRead.memeHook(factory);
    }

    function launchHookFeeBps(address hook, bytes32 poolId) external view returns (bool readable, uint256 feeBps) {
        return PonsRead.launchHookFeeBps(hook, poolId);
    }
}

contract PonsReadTest is Test {
    address internal constant TOKEN = address(0xA11CE);
    address internal constant HOOK = address(0xB0B);
    bytes32 internal constant POOL_ID = keccak256("pool");

    PonsReadHarness internal harness;
    address internal factoryTarget;
    address internal hookTarget;

    function setUp() public {
        harness = new PonsReadHarness();
        factoryTarget = address(new EmptyPonsReadTarget());
        hookTarget = address(new EmptyPonsReadTarget());
    }

    function test_LaunchRecordSummaryAcceptsCanonicalReturn() public {
        _mockRecord(_record(uint160(TOKEN), 0, 0, 200, 100, 1));

        (
            bool readable,
            address actualToken,
            address pairToken,
            uint24 poolFee,
            int24 tickSpacing,
            uint16 creatorTaxBps,
            bool exists
        ) = harness.launchRecordSummary(factoryTarget, TOKEN);
        assertTrue(readable);
        assertEq(actualToken, TOKEN);
        assertEq(pairToken, address(0));
        assertEq(poolFee, 0);
        assertEq(tickSpacing, 200);
        assertEq(creatorTaxBps, 100);
        assertTrue(exists);
    }

    function test_LaunchRecordSummaryRejectsCallFailureAndShortReturn() public {
        vm.mockCallRevert(factoryTarget, _recordCall(), bytes("unreadable"));
        _assertRecordUnreadableWithoutRemock();
        _assertRecordUnreadable(new bytes(14 * 32));
    }

    function test_LaunchRecordSummaryRejectsEveryMalformedWordGuard() public {
        uint256 dirtyToken = uint256(uint160(TOKEN)) | (uint256(1) << 160);
        uint256 dirtyPair = uint256(uint160(address(0xCAFE))) | (uint256(1) << 160);
        _assertRecordUnreadable(_record(dirtyToken, 0, 0, 200, 100, 1));
        _assertRecordUnreadable(_record(uint160(TOKEN), dirtyPair, 0, 200, 100, 1));
        _assertRecordUnreadable(_record(uint160(TOKEN), 0, uint256(type(uint24).max) + 1, 200, 100, 1));
        _assertRecordUnreadable(_record(uint160(TOKEN), 0, 0, 8_388_608, 100, 1));
        _assertRecordUnreadable(_record(uint160(TOKEN), 0, 0, type(uint256).max - 8_388_608, 100, 1));
        _assertRecordUnreadable(_record(uint160(TOKEN), 0, 0, 200, uint256(type(uint16).max) + 1, 1));
        _assertRecordUnreadable(_record(uint160(TOKEN), 0, 0, 200, 100, 2));
    }

    function test_MemeHookAcceptsCanonicalReturn_RejectsFailureShortAndDirtyWord() public {
        bytes memory callData = abi.encodeWithSelector(IPonsFactoryView.memeHook.selector);
        vm.mockCall(factoryTarget, callData, abi.encode(HOOK));
        (bool readable, address hook) = harness.memeHook(factoryTarget);
        assertTrue(readable);
        assertEq(hook, HOOK);

        vm.clearMockedCalls();
        vm.mockCallRevert(factoryTarget, callData, bytes("unreadable"));
        (readable, hook) = harness.memeHook(factoryTarget);
        assertFalse(readable);
        assertEq(hook, address(0));

        vm.clearMockedCalls();
        vm.mockCall(factoryTarget, callData, new bytes(31));
        (readable, hook) = harness.memeHook(factoryTarget);
        assertFalse(readable);
        assertEq(hook, address(0));

        vm.clearMockedCalls();
        vm.mockCall(factoryTarget, callData, abi.encode(uint256(uint160(HOOK)) | (uint256(1) << 160)));
        (readable, hook) = harness.memeHook(factoryTarget);
        assertFalse(readable);
        assertEq(hook, address(0));
    }

    function test_LaunchHookFeeAcceptsCanonicalReturn_RejectsFailureShortAndBadInitializedWord() public {
        bytes memory callData = abi.encodeWithSelector(IPonsHookView.launches.selector, POOL_ID);
        uint256[13] memory words;
        words[0] = 1;
        words[10] = 350;
        vm.mockCall(hookTarget, callData, abi.encode(words));
        (bool readable, uint256 feeBps) = harness.launchHookFeeBps(hookTarget, POOL_ID);
        assertTrue(readable);
        assertEq(feeBps, 350);

        vm.clearMockedCalls();
        vm.mockCallRevert(hookTarget, callData, bytes("unreadable"));
        _assertLaunchFeeUnreadable();

        vm.clearMockedCalls();
        vm.mockCall(hookTarget, callData, new bytes(12 * 32));
        _assertLaunchFeeUnreadable();

        words[0] = 0;
        vm.clearMockedCalls();
        vm.mockCall(hookTarget, callData, abi.encode(words));
        _assertLaunchFeeUnreadable();

        words[0] = 2;
        vm.clearMockedCalls();
        vm.mockCall(hookTarget, callData, abi.encode(words));
        _assertLaunchFeeUnreadable();
    }

    function _assertRecordUnreadable(bytes memory returnData) private {
        _mockRecord(returnData);
        _assertRecordUnreadableWithoutRemock();
    }

    function _assertRecordUnreadableWithoutRemock() private view {
        (
            bool readable,
            address actualToken,
            address pairToken,
            uint24 poolFee,
            int24 tickSpacing,
            uint16 creatorTaxBps,
            bool exists
        ) = harness.launchRecordSummary(factoryTarget, TOKEN);
        assertFalse(readable);
        assertEq(actualToken, address(0));
        assertEq(pairToken, address(0));
        assertEq(poolFee, 0);
        assertEq(tickSpacing, 0);
        assertEq(creatorTaxBps, 0);
        assertFalse(exists);
    }

    function _assertLaunchFeeUnreadable() private view {
        (bool readable, uint256 feeBps) = harness.launchHookFeeBps(hookTarget, POOL_ID);
        assertFalse(readable);
        assertEq(feeBps, 0);
    }

    function _mockRecord(bytes memory returnData) private {
        vm.clearMockedCalls();
        vm.mockCall(factoryTarget, _recordCall(), returnData);
    }

    function _recordCall() private pure returns (bytes memory) {
        return abi.encodeWithSelector(IPons.getLaunchedToken.selector, TOKEN);
    }

    function _record(
        uint256 tokenWord,
        uint256 pairWord,
        uint256 feeWord,
        uint256 tickWord,
        uint256 taxWord,
        uint256 existsWord
    ) private pure returns (bytes memory) {
        uint256[15] memory words;
        words[0] = tokenWord;
        words[4] = pairWord;
        words[6] = feeWord;
        words[7] = tickWord;
        words[8] = taxWord;
        words[14] = existsWord;
        return abi.encode(words);
    }
}
