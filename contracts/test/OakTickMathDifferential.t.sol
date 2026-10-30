// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {OakTickMath} from "../src/OakOracle.sol";

/// @dev Test-only snapshot of getSqrtRatioAtTick from Uniswap/v3-core at
///      https://github.com/Uniswap/v3-core/blob/5ea68a77cb541c6b3812df783be71ba8c081e25f/contracts/libraries/TickMath.sol
///      licensed GPL-2.0-or-later. It is retained only as a differential oracle
///      for Oak's MIT-licensed v4-core adaptation and is never deployed.
library LegacyV3TickMathReference {
    int24 internal constant MAX_TICK = 887272;

    error TickOutOfBounds();

    function sqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
        if (absTick > uint256(uint24(MAX_TICK))) revert TickOutOfBounds();

        uint256 ratio = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;
        sqrtPriceX96 = uint160((ratio >> 32) + (ratio & type(uint32).max == 0 ? 0 : 1));
    }
}

contract OakTickMathDifferentialTest is Test {
    int24 private constant MIN_TICK = -887_272;
    int24 private constant MAX_TICK = 887_272;

    error DifferentialMismatch(int24 tick, uint160 expected, uint160 actual);

    function test_BoundariesMatchReference() public pure {
        int24[7] memory ticks = [MIN_TICK, MIN_TICK + 1, int24(-1), int24(0), int24(1), MAX_TICK - 1, MAX_TICK];
        for (uint256 i; i < ticks.length; ++i) {
            _assertMatches(ticks[i], false);
        }
    }

    function test_EveryPowerOfTwoTransitionMatchesReference() public pure {
        for (uint256 bit; bit < 20; ++bit) {
            int24 transition = int24(int256(1 << bit));
            _assertMatches(transition - 1, false);
            _assertMatches(transition, false);
            _assertMatches(transition + 1, false);
            _assertMatches(-transition - 1, false);
            _assertMatches(-transition, false);
            _assertMatches(-transition + 1, false);
        }
    }

    function test_StridedDomainAndNeighborsMatchReferenceAndAreMonotonic() public pure {
        for (int256 cursor = -887_000; cursor <= 887_000; cursor += 1_000) {
            int24 tick = int24(cursor);
            _assertMatches(tick - 1, false);
            _assertMatches(tick, false);
            _assertMatches(tick + 1, false);
            assertLt(OakTickMath.sqrtRatioAtTick(tick - 1), OakTickMath.sqrtRatioAtTick(tick));
            assertLt(OakTickMath.sqrtRatioAtTick(tick), OakTickMath.sqrtRatioAtTick(tick + 1));
        }
    }

    /// @dev The `tickmath` Foundry profile runs this property 100,000 times.
    function testFuzz_RandomTickMatchesReferenceAndAdjacentTicksAreMonotonic(int24 rawTick) public pure {
        int24 tick = int24(bound(int256(rawTick), int256(MIN_TICK), int256(MAX_TICK) - 1));
        _assertMatches(tick, false);
        _assertMatches(tick + 1, false);
        assertLt(OakTickMath.sqrtRatioAtTick(tick), OakTickMath.sqrtRatioAtTick(tick + 1));
    }

    function test_RejectsBothOutOfRangeTicks() public {
        vm.expectRevert(OakTickMath.TickOutOfBounds.selector);
        this.current(MIN_TICK - 1);
        vm.expectRevert(OakTickMath.TickOutOfBounds.selector);
        this.current(MAX_TICK + 1);
    }

    function test_PositiveControlRejectsOneUnitMutant() public {
        int24 tick = 1;
        uint160 expected = LegacyV3TickMathReference.sqrtRatioAtTick(tick);
        uint160 mutant = OakTickMath.sqrtRatioAtTick(tick) + 1;
        vm.expectRevert(abi.encodeWithSelector(DifferentialMismatch.selector, tick, expected, mutant));
        this.assertMatchesOneUnitMutant(tick);
    }

    /// @dev Opt in with OAK_TICKMATH_EXHAUSTIVE=true and a 10,000,000,000 local test gas limit.
    ///      The default suite reports this test skipped.
    function test_ExhaustiveDomainMatchesReferenceAndIsStrictlyMonotonic() public {
        vm.skip(!vm.envOr("OAK_TICKMATH_EXHAUSTIVE", false));

        uint160 previous;
        for (int256 cursor = int256(MIN_TICK); cursor <= int256(MAX_TICK); ++cursor) {
            int24 tick = int24(cursor);
            _assertMatches(tick, false);
            uint160 currentPrice = OakTickMath.sqrtRatioAtTick(tick);
            if (tick != MIN_TICK) assertLt(previous, currentPrice);
            previous = currentPrice;
        }
    }

    function current(int24 tick) external pure returns (uint160) {
        return OakTickMath.sqrtRatioAtTick(tick);
    }

    function assertMatchesOneUnitMutant(int24 tick) external pure {
        _assertMatches(tick, true);
    }

    function _assertMatches(int24 tick, bool mutate) private pure {
        uint160 expected = LegacyV3TickMathReference.sqrtRatioAtTick(tick);
        uint160 actual = OakTickMath.sqrtRatioAtTick(tick);
        if (mutate) ++actual;
        if (actual != expected) revert DifferentialMismatch(tick, expected, actual);
    }
}
