// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {OakPricing} from "../src/libraries/OakPricing.sol";
import {PonsSelectors} from "../src/interfaces/IPons.sol";

contract OakPricingTest is Test {
    using stdJson for string;

    error NonCanonicalV212Encoding();

    struct PoolKey {
        address currency0;
        address currency1;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
    }

    struct V212SwapParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMinimum;
        uint256 minHopPriceX36;
        bytes hookData;
    }

    struct LegacyFiveFieldSwapParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMinimum;
        bytes hookData;
    }

    string internal vectors;

    function setUp() public {
        vectors = vm.readFile("test/vectors.json");
    }

    function test_EntryCurveMatchesVectors() public view {
        for (uint256 i; i < 10; ++i) {
            string memory base = string.concat(".pricing.entryCurve[", vm.toString(i), "]");
            assertEq(
                OakPricing.entryUsdE18(_u(string.concat(base, ".marketCapUsdE18"))),
                _u(string.concat(base, ".entryUsdE18"))
            );
        }
    }

    function test_EntryCurveContinuousAtBreakpoints() public view {
        for (uint256 i; i < 4; ++i) {
            uint256 breakpoint = _u(string.concat(".pricing.continuityBreakpointsUsdE18[", vm.toString(i), "]"));
            uint256 left = OakPricing.entryUsdE18(breakpoint - 1);
            uint256 at = OakPricing.entryUsdE18(breakpoint);
            uint256 right = OakPricing.entryUsdE18(breakpoint + 1);
            assertLe(left, at);
            assertLe(at, right);
            assertLe(at - left, 1);
            assertLe(right - at, 1);
        }
    }

    function testFuzz_EntryCurveContinuousAtBreakpoints(uint96 rawDistance) public view {
        uint256 distance = bound(uint256(rawDistance), 1, 1e18);
        for (uint256 i; i < 4; ++i) {
            uint256 breakpoint = _u(string.concat(".pricing.continuityBreakpointsUsdE18[", vm.toString(i), "]"));
            uint256 left = OakPricing.entryUsdE18(breakpoint - distance);
            uint256 at = OakPricing.entryUsdE18(breakpoint);
            uint256 right = OakPricing.entryUsdE18(breakpoint + distance);
            assertLe(left, at);
            assertLe(at, right);
            assertGe(left, 20e18);
            assertLe(right, 300e18);
        }
    }

    function test_NoHoldPriceVectors() public view {
        for (uint256 i; i < 4; ++i) {
            string memory base = string.concat(".pricing.noHold[", vm.toString(i), "]");
            assertEq(
                OakPricing.noHoldPriceBase(_u(string.concat(base, ".entryUsdE18"))),
                _u(string.concat(base, ".priceUsdgE6"))
            );
        }
    }

    function test_NoHoldFloorConstantEqualsCurveAtZero() public pure {
        assertEq(OakPricing.NOHOLD_FLOOR, OakPricing.noHoldPriceBase(OakPricing.entryUsdE18(0)));
    }

    function test_SplitVectorsSumToAmount() public view {
        for (uint256 i; i < 2; ++i) {
            string memory base = string.concat(".pricing.splits[", vm.toString(i), "]");
            uint256 amount = _u(string.concat(base, ".amount"));
            (uint256 burn, uint256 treasury) = OakPricing.splitBurn(amount);
            assertEq(burn, _u(string.concat(base, ".burn")));
            assertEq(treasury, _u(string.concat(base, ".treasury")));
            assertEq(burn + treasury, amount);
        }
    }

    function testFuzz_SplitVectorsSumToAmount(uint256 amount) public pure {
        (uint256 burn, uint256 treasury) = OakPricing.splitBurn(amount);
        assertEq(burn + treasury, amount);
        assertEq(burn, amount / 4);
    }

    function test_SignupBurnCeil() public view {
        uint256 count = _u(".pricing.signupBurn.count");
        uint256 burn = OakPricing.signupBurn(count);
        assertEq(burn, _u(".pricing.signupBurn.burn"));
        assertEq(count - burn, _u(".pricing.signupBurn.tracked"));
        for (uint256 i; i < 5; ++i) {
            string memory base = string.concat(".pricing.signupBurn.ceilCases[", vm.toString(i), "]");
            count = _u(string.concat(base, ".count"));
            burn = OakPricing.signupBurn(count);
            assertEq(burn, _u(string.concat(base, ".burn")));
            assertEq(count - burn, _u(string.concat(base, ".tracked")));
        }
    }

    function testFuzz_SignupBurnCeil(uint256 count) public pure {
        uint256 burn = OakPricing.signupBurn(count);
        assertLe(burn, count);
        uint256 expected = count / 20 + (count % 20 == 0 ? 0 : 1);
        assertEq(burn, expected);
        assertEq((count - burn) + burn, count);
    }

    function test_RequiredCountRoundsUp_ParameterisedByDecimals() public view {
        for (uint256 i; i < 4; ++i) {
            string memory base = string.concat(".pricing.requiredCount[", vm.toString(i), "]");
            uint256 actual = OakPricing.requiredCount(
                _u(string.concat(base, ".entryUsdE18")),
                _u(string.concat(base, ".oakUsdE18")),
                uint8(_u(string.concat(base, ".oakDecimals")))
            );
            assertEq(actual, _u(string.concat(base, ".count")));
        }
        assertEq(_u(".pricing.requiredCount[0].count") / _u(".pricing.requiredCount[1].count"), 1e12);
    }

    function testFuzz_RequiredCountIsMinimalCeiling(uint128 entryRaw, uint128 oakUsdRaw, uint8 decimalsRaw)
        public
        pure
    {
        uint256 entry = uint256(entryRaw);
        uint256 oakUsd = bound(uint256(oakUsdRaw), 1, type(uint128).max);
        uint8 decimals = uint8(bound(uint256(decimalsRaw), 0, 18));
        uint256 numerator = entry * (10 ** uint256(decimals));
        uint256 count = OakPricing.requiredCount(entry, oakUsd, decimals);

        assertGe(count * oakUsd, numerator);
        if (count != 0) assertLt((count - 1) * oakUsd, numerator);
    }

    function test_OakUsdFromAveragesVector() public view {
        uint256 weightedNumerator;
        uint256 totalVolume;
        uint256 unweighted;
        for (uint256 i; i < 3; ++i) {
            uint256 volume = _u(string.concat(".average.ethVolumeWei[", vm.toString(i), "]"));
            uint256 price = _u(string.concat(".average.oakPerEthE18[", vm.toString(i), "]"));
            weightedNumerator += volume * price;
            totalVolume += volume;
            unweighted += price;
        }
        uint256 weighted = weightedNumerator / totalVolume;
        assertEq(weighted, _u(".average.weightedMeanE18"));
        assertEq(unweighted / 3, _u(".average.unweightedMeanE18"));
        assertNotEq(weighted, unweighted / 3);
        assertEq(_u(".average.timeWeightedMeanE18"), unweighted / 3);
        assertEq(OakPricing.oakUsdE18(_u(".oracle.ethUsd.ethUsdE18"), weighted), _u(".average.oakUsdE18"));
        assertEq(
            OakPricing.oakUsdE18(_u(".pricing.oakUsd.ethUsdE18"), _u(".pricing.oakUsd.oakPerEthE18")),
            _u(".pricing.oakUsd.oakUsdE18")
        );
    }

    function test_BurnerMinOutVectors_18And6Decimals() public view {
        for (uint256 i; i < 2; ++i) {
            string memory base = string.concat(".pricing.burnerMinOut[", vm.toString(i), "]");
            assertEq(
                OakPricing.burnerMinOut(
                    _u(string.concat(base, ".usdgIn")),
                    _u(string.concat(base, ".oakPerEthE18")),
                    _u(string.concat(base, ".ethUsdE18")),
                    uint8(_u(string.concat(base, ".oakDecimals"))),
                    OakPricing.MAX_BURNER_FLOOR_BPS
                ),
                _u(string.concat(base, ".minOut"))
            );
        }
    }

    function testFuzz_BurnerMinOutMatchesFloorFormula(
        uint64 usdgInRaw,
        uint128 oakPerEthRaw,
        uint128 ethUsdRaw,
        uint8 decimalsRaw
    ) public pure {
        uint256 oakPerEth = bound(uint256(oakPerEthRaw), 1, type(uint128).max);
        uint256 ethUsd = bound(uint256(ethUsdRaw), 1, type(uint128).max);
        uint8 decimals = uint8(bound(uint256(decimalsRaw), 6, 18));
        uint256 numerator =
            uint256(usdgInRaw) * (10 ** uint256(decimals - 6)) * oakPerEth * OakPricing.MAX_BURNER_FLOOR_BPS;
        uint256 expected = numerator / (ethUsd * 10_000);

        assertEq(
            OakPricing.burnerMinOut(usdgInRaw, oakPerEth, ethUsd, decimals, OakPricing.MAX_BURNER_FLOOR_BPS), expected
        );
    }

    function test_BurnerFeeFloorBounds() public pure {
        assertEq(OakPricing.burnerFloorBps(100, 100), OakPricing.MAX_BURNER_FLOOR_BPS);
        assertEq(OakPricing.burnerFloorBps(350, 100), 9_400);
        assertEq(OakPricing.burnerFloorBps(750, 100), OakPricing.MIN_BURNER_FLOOR_BPS);
    }

    function test_BurnerFeeFloorRejectsPolicyBelowDocumentedMinimum() public {
        vm.expectRevert(abi.encodeWithSelector(OakPricing.FeePolicyOutOfBounds.selector, 751, 100));
        this.burnerFloorBps(751, 100);
    }

    function burnerFloorBps(uint256 hookFeeBps, uint256 creatorTaxBps) external pure returns (uint256) {
        return OakPricing.burnerFloorBps(hookFeeBps, creatorTaxBps);
    }

    function test_EthUsdAndSpotConversionVectors() public view {
        int256 first = _i(".oracle.ethUsd.tickCumulatives[0]");
        int256 second = _i(".oracle.ethUsd.tickCumulatives[1]");
        int256 seconds_ = int256(_u(".oracle.ethUsd.seconds"));
        int256 delta = second - first;
        int256 truncated = delta / seconds_;
        int256 meanTick = truncated - (delta < 0 && delta % seconds_ != 0 ? int256(1) : int256(0));
        assertEq(delta, _i(".oracle.ethUsd.delta"));
        assertEq(truncated, _i(".oracle.ethUsd.wrongTruncatedTick"));
        assertEq(meanTick, _i(".oracle.ethUsd.meanTick"));

        uint256 q192 = 1 << 192;
        uint256 ethSqrt = _u(".oracle.ethUsd.sqrtRatioAtMeanTickX96");
        uint256 spotSqrt = _u(".oracle.spot.sqrtPriceX96");
        assertEq(Math.mulDiv(ethSqrt, ethSqrt * 1e30, q192), _u(".oracle.ethUsd.ethUsdE18"));
        assertEq(Math.mulDiv(spotSqrt, spotSqrt * 1e18, q192), _u(".oracle.spot.oakPerEthE18"));
    }

    function test_MarketCapNoDoubleSubtraction() public view {
        uint256 totalSupplyAfter = _u(".pricing.marketCap.totalSupplyAfter");
        uint256 deadBalance = _u(".pricing.marketCap.deadAddressBalance");
        uint256 oakUsd = _u(".pricing.marketCap.oakUsdE18");
        uint256 expected = _u(".pricing.marketCap.marketCapUsdE18");
        assertEq(OakPricing.marketCapUsdE18(totalSupplyAfter, oakUsd, 18), expected);
        assertNotEq(OakPricing.marketCapUsdE18(totalSupplyAfter - deadBalance, oakUsd, 18), expected);
    }

    function test_MaxCountAndPriceBoundaryVectors() public view {
        uint256 count = _u(".pricing.maxBoundaries.count");
        uint256 maxCountAccepted = _u(".pricing.maxBoundaries.maxCountAccepted");
        uint256 maxCountRejected = _u(".pricing.maxBoundaries.maxCountRejected");
        assertEq(maxCountAccepted, count);
        assertEq(maxCountRejected + 1, count);
        assertLe(count, maxCountAccepted);
        assertGt(count, maxCountRejected);
        uint256 price = _u(".pricing.maxBoundaries.price");
        uint256 maxPriceAccepted = _u(".pricing.maxBoundaries.maxPriceAccepted");
        uint256 maxPriceRejected = _u(".pricing.maxBoundaries.maxPriceRejected");
        assertEq(maxPriceAccepted, price);
        assertEq(maxPriceRejected + 1, price);
        assertLe(price, maxPriceAccepted);
        assertGt(price, maxPriceRejected);
    }

    function test_V212SixFieldRouteAndNegativeControls() public {
        bytes memory payload = vectors.readBytes(".router.buyPayload");
        (bytes memory actions, bytes[] memory params) = abi.decode(payload, (bytes, bytes[]));
        assertEq(actions, vectors.readBytes(".router.actions"));
        assertEq(params.length, 3);

        V212SwapParams memory swap = abi.decode(params[0], (V212SwapParams));
        assertTrue(swap.zeroForOne);
        assertEq(swap.minHopPriceX36, 0);
        assertEq(swap.hookData, hex"");
        assertEq(abi.encode(swap), params[0]);

        (address settleCurrency, uint256 maxAmountIn) = abi.decode(params[1], (address, uint256));
        (address takeCurrency, uint256 minAmountOut) = abi.decode(params[2], (address, uint256));
        assertEq(settleCurrency, swap.poolKey.currency0);
        assertEq(maxAmountIn, swap.amountIn);
        assertEq(takeCurrency, swap.poolKey.currency1);
        assertEq(minAmountOut, swap.amountOutMinimum);

        V212SwapParams memory alteredSwap =
            V212SwapParams(swap.poolKey, swap.zeroForOne, swap.amountIn, swap.amountOutMinimum, 1, swap.hookData);
        bytes memory altered = abi.encode(alteredSwap);
        assertNotEq(keccak256(altered), keccak256(params[0]));
        assertEq(this.decodeSixMinHop(altered), 1);

        LegacyFiveFieldSwapParams memory legacy = LegacyFiveFieldSwapParams(
            swap.poolKey, swap.zeroForOne, swap.amountIn, swap.amountOutMinimum, swap.hookData
        );
        bytes memory fiveField = abi.encode(legacy);
        vm.expectRevert();
        this.decodeSixMinHop(fiveField);
    }

    function test_LaunchRouterCalldataAssertions() public view {
        bytes4 executeSelector = bytes4(vectors.readBytes(".router.executeSelector"));
        assertEq(executeSelector, bytes4(keccak256("execute(bytes,bytes[],uint256)")));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = vectors.readBytes(".router.buyPayload");
        bytes memory callData = abi.encodeWithSelector(
            executeSelector, vectors.readBytes(".router.commands"), inputs, uint256(1_800_000_000)
        );
        assertEq(bytes4(callData), executeSelector);
        (bytes memory commands, bytes[] memory decodedInputs, uint256 deadline) =
            abi.decode(_withoutSelector(callData), (bytes, bytes[], uint256));
        assertEq(commands, hex"10");
        assertEq(decodedInputs[0], inputs[0]);
        assertEq(deadline, 1_800_000_000);
        assertEq(vectors.readAddress(".router.address"), PonsSelectors.UNIVERSAL_ROUTER_V2_1_2);

        bytes4 launchAndBuy = bytes4(vectors.readBytes(".ponsLaunchRouter.launchAndBuySelector"));
        bytes memory literalLaunchCalldata = abi.encodePacked(launchAndBuy);
        assertEq(bytes4(literalLaunchCalldata), PonsSelectors.LAUNCH_AND_BUY);
        assertEq(vectors.readAddress(".ponsLaunchRouter.address"), PonsSelectors.LAUNCH_ROUTER);
        assertNotEq(launchAndBuy, bytes4(keccak256("createGraduatedPool(address)")));
    }

    function decodeSixMinHop(bytes calldata encoded) external pure returns (uint256 minHopPriceX36) {
        V212SwapParams memory swap = abi.decode(encoded, (V212SwapParams));
        if (keccak256(abi.encode(swap)) != keccak256(encoded)) revert NonCanonicalV212Encoding();
        return swap.minHopPriceX36;
    }

    function _withoutSelector(bytes memory data) internal pure returns (bytes memory result) {
        result = new bytes(data.length - 4);
        for (uint256 i; i < result.length; ++i) {
            result[i] = data[i + 4];
        }
    }

    function _u(string memory path) internal view returns (uint256) {
        return vm.parseUint(vectors.readString(path));
    }

    function _i(string memory path) internal view returns (int256) {
        return vm.parseInt(vectors.readString(path));
    }
}
