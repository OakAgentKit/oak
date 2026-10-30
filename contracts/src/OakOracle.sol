// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IOakOracle} from "./interfaces/IOakOracle.sol";
import {IPons} from "./interfaces/IPons.sol";
import {PriceNote, OakPriceNote} from "./libraries/OakPriceNote.sol";

/// @dev Adapted from Uniswap v4-core src/libraries/TickMath.sol at commit
///      0f17b65aa61edee384d5129b7ea080f22905faa0 (https://github.com/Uniswap/v4-core), MIT.
///      Modifications: renamed the library and getSqrtPriceAtTick function; replaced
///      CustomRevert and InvalidTick(int24) with the plain TickOutOfBounds error; removed
///      unused constants, imports, spacing helpers, and sqrt-price-to-tick conversion; and
///      pinned the file's existing Solidity 0.8.26 pragma. The algorithm and constants in
///      sqrtRatioAtTick are otherwise unchanged.
library OakTickMath {
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = 887272;

    error TickOutOfBounds();

    function sqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        unchecked {
            uint256 absTick;
            assembly ("memory-safe") {
                tick := signextend(2, tick)
                // mask = 0 if tick >= 0 else -1 (all 1s)
                let mask := sar(255, tick)
                // if tick >= 0, |tick| = tick = 0 ^ tick
                // if tick < 0, |tick| = ~~|tick| = ~(-|tick| - 1) = ~(tick - 1) = (-1) ^ (tick - 1)
                // either way, |tick| = mask ^ (tick + mask)
                absTick := xor(mask, add(mask, tick))
            }

            if (absTick > uint256(int256(MAX_TICK))) revert TickOutOfBounds();

            // The tick is decomposed into bits, and for each bit with index i that is set, the product of
            // 1/sqrt(1.0001^(2^i)) is calculated (using Q128.128). The constants are rounded to the nearest integer.
            uint256 price;
            assembly ("memory-safe") {
                price := xor(shl(128, 1), mul(xor(shl(128, 1), 0xfffcb933bd6fad37aa2d162d1a594001), and(absTick, 0x1)))
            }
            if (absTick & 0x2 != 0) price = (price * 0xfff97272373d413259a46990580e213a) >> 128;
            if (absTick & 0x4 != 0) price = (price * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
            if (absTick & 0x8 != 0) price = (price * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
            if (absTick & 0x10 != 0) price = (price * 0xffcb9843d60f6159c9db58835c926644) >> 128;
            if (absTick & 0x20 != 0) price = (price * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
            if (absTick & 0x40 != 0) price = (price * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
            if (absTick & 0x80 != 0) price = (price * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
            if (absTick & 0x100 != 0) price = (price * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
            if (absTick & 0x200 != 0) price = (price * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
            if (absTick & 0x400 != 0) price = (price * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
            if (absTick & 0x800 != 0) price = (price * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
            if (absTick & 0x1000 != 0) price = (price * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
            if (absTick & 0x2000 != 0) price = (price * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
            if (absTick & 0x4000 != 0) price = (price * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
            if (absTick & 0x8000 != 0) price = (price * 0x31be135f97d08fd981231505542fcfa6) >> 128;
            if (absTick & 0x10000 != 0) price = (price * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
            if (absTick & 0x20000 != 0) price = (price * 0x5d6af8dedb81196699c329225ee604) >> 128;
            if (absTick & 0x40000 != 0) price = (price * 0x2216e584f5fa1ea926041bedfe98) >> 128;
            if (absTick & 0x80000 != 0) price = (price * 0x48a170391f7dc42444e8fa2) >> 128;

            assembly ("memory-safe") {
                // if (tick > 0) price = type(uint256).max / price;
                if sgt(tick, 0) { price := div(not(0), price) }

                // Divide by 1 << 32 and round up from Q128.128 to Q128.96.
                sqrtPriceX96 := shr(32, add(price, sub(shl(32, 1), 1)))
            }
        }
    }
}

/// @notice Immutable Oak pricing sources and consumer-bound price-note verification.
contract OakOracle is IOakOracle {
    uint8 public constant CURVE = 0;
    uint8 public constant READY = 1;
    uint256 private constant NOTE_TTL = 300;
    uint256 private constant AVERAGE_WINDOW = 1800;
    uint256 private constant Q96 = 1 << 96;
    uint256 private constant Q192 = 1 << 192;
    uint256 private constant ETH_USD_SCALE = 1e30;
    uint256 private constant OAK_ETH_SCALE = 1e18;
    address public constant PONS_HOOK = 0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044;

    bytes4 private constant OBSERVE_SELECTOR = bytes4(keccak256("observe(uint32[])"));
    bytes4 private constant REAL_QUOTE_RESERVE_SELECTOR = bytes4(keccak256("realQuoteReserve()"));

    address public immutable ponsFactory;
    address public immutable oakToken;
    address public immutable poolManager;
    address public immutable ethUsdgPool;
    address public immutable safe;
    bytes32 public immutable poolId;
    bytes32 public immutable spotStorageSlot;

    address public priceSigner;
    bool public readyLatched;

    error OnlySafe();

    constructor(
        address ponsFactory_,
        address oakToken_,
        address poolManager_,
        address ethUsdgPool_,
        address safe_,
        address priceSigner_
    ) {
        ponsFactory = ponsFactory_;
        oakToken = oakToken_;
        poolManager = poolManager_;
        ethUsdgPool = ethUsdgPool_;
        safe = safe_;
        priceSigner = priceSigner_;

        bytes32 id = keccak256(abi.encode(address(0), oakToken_, uint24(0), int24(200), PONS_HOOK));
        poolId = id;
        spotStorageSlot = keccak256(abi.encodePacked(id, uint256(6)));
    }

    function phase() public view returns (uint8) {
        (bool readable, uint8 p,) = _launchRecord();
        if (!readable) revert OracleUnreadable(ponsFactory);
        return readyLatched || p == 2 ? READY : CURVE;
    }

    /// @notice Persist graduation on a transaction; view calls cannot write the latch.
    function syncPhase() external returns (uint8 current) {
        current = phase();
        if (current == READY) readyLatched = true;
    }

    function available() external view returns (bool) {
        return phase() == READY;
    }

    function ethUsdE18() public view returns (uint256 value) {
        (int56 first, int56 second) = _tickCumulatives();
        int256 delta = int256(second) - int256(first);
        int256 meanTick = delta / int256(AVERAGE_WINDOW);
        if (delta < 0 && delta % int256(AVERAGE_WINDOW) != 0) --meanTick;
        if (meanTick < int256(OakTickMath.MIN_TICK) || meanTick > int256(OakTickMath.MAX_TICK)) {
            revert OracleUnreadable(ethUsdgPool);
        }

        uint160 sqrtPriceX96 = OakTickMath.sqrtRatioAtTick(int24(meanTick));
        value = _scaledSquare(sqrtPriceX96, ETH_USD_SCALE);
        if (value == 0) revert OracleUnreadable(ethUsdgPool);
    }

    function spotOakPerEthE18() public view returns (uint256 value) {
        if (phase() != READY) revert NotReady();
        value = _scaledSquare(_readSqrtPrice(), OAK_ETH_SCALE);
        if (value == 0) revert OracleUnreadable(poolManager);
    }

    function verifyNote(PriceNote calldata n, bytes calldata sig, address boundWallet)
        external
        view
        returns (uint256 oakPerEthE18)
    {
        if (phase() != READY) revert NotReady();
        if (n.wallet != boundWallet) revert NoteWrongWallet();
        if (uint256(n.timestamp) > block.timestamp) revert NoteNotYetValid();
        if (uint256(n.timestamp) + NOTE_TTL < block.timestamp) revert NoteExpired();

        address signer = priceSigner;
        if (signer == address(0) || OakPriceNote.recover(n, sig, msg.sender) != signer) {
            revert NoteBadSignature();
        }

        uint256 spot = spotOakPerEthE18();
        if (!_insideGuard(n.oakPerEthE18, spot)) revert NoteOutsideGuard(spot, n.oakPerEthE18);
        return n.oakPerEthE18;
    }

    function liquidityUsdgE6() external view returns (uint256) {
        (bool readable, uint8 p, address curve) = _launchRecord();
        if (!readable) revert OracleUnreadable(ponsFactory);
        uint256 ethUsd = ethUsdE18();

        if (readyLatched || p == 2) {
            uint160 sqrtPriceX96 = _readSqrtPrice();
            bytes32 liquiditySlot;
            unchecked {
                liquiditySlot = bytes32(uint256(spotStorageSlot) + 3);
            }
            uint128 liquidity = uint128(uint256(_readPoolWord(liquiditySlot)));
            uint256 virtualEthWei = Math.mulDiv(uint256(liquidity), Q96, sqrtPriceX96);
            return Math.mulDiv(virtualEthWei, ethUsd, ETH_USD_SCALE) * 2;
        }

        if (curve == address(0)) revert OracleUnreadable(ponsFactory);
        (bool ok, bytes memory data) = curve.staticcall(abi.encodeWithSelector(REAL_QUOTE_RESERVE_SELECTOR));
        if (!ok || data.length < 32) revert OracleUnreadable(curve);
        uint256 realQuoteReserve;
        assembly ("memory-safe") {
            realQuoteReserve := mload(add(data, 0x20))
        }
        return Math.mulDiv(realQuoteReserve, ethUsd, ETH_USD_SCALE);
    }

    function supplyNet() external view returns (uint256) {
        return IERC20(oakToken).totalSupply();
    }

    function setPriceSigner(address signer) external {
        if (msg.sender != safe) revert OnlySafe();
        priceSigner = signer;
        emit PriceSignerSet(signer);
    }

    /// @dev Overflow-safe algebraic equivalent of note*2 >= spot && note*2 <= spot*3.
    ///      The lower bound deliberately rounds up for odd spot values.
    function _insideGuard(uint256 note, uint256 spot) private pure returns (bool) {
        uint256 lower = spot / 2 + spot % 2;
        if (note < lower) return false;
        uint256 half = spot / 2;
        if (spot > type(uint256).max - half) return true;
        return note <= spot + half;
    }

    function _launchRecord() private view returns (bool readable, uint8 p, address curve) {
        (bool ok, bytes memory data) =
            ponsFactory.staticcall(abi.encodeWithSelector(IPons.getLaunchedToken.selector, oakToken));
        if (!ok || data.length < 11 * 32) return (false, 0, address(0));

        uint256 curveWord;
        uint256 phaseWord;
        assembly ("memory-safe") {
            curveWord := mload(add(data, 0x40))
            phaseWord := mload(add(data, 0x160))
        }
        if (curveWord >> 160 != 0 || phaseWord > 2) return (false, 0, address(0));
        return (true, uint8(phaseWord), address(uint160(curveWord)));
    }

    function _tickCumulatives() private view returns (int56 first, int56 second) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = uint32(AVERAGE_WINDOW);
        (bool ok, bytes memory data) = ethUsdgPool.staticcall(abi.encodeWithSelector(OBSERVE_SELECTOR, secondsAgos));
        if (!ok || data.length < 256) revert OracleUnreadable(ethUsdgPool);

        uint256 firstOffset;
        uint256 secondOffset;
        uint256 firstLength;
        uint256 secondLength;
        int256 firstWord;
        int256 secondWord;
        uint256 secondsPerLiquidity0;
        uint256 secondsPerLiquidity1;
        assembly ("memory-safe") {
            firstOffset := mload(add(data, 0x20))
            secondOffset := mload(add(data, 0x40))
            firstLength := mload(add(data, 0x60))
            firstWord := mload(add(data, 0x80))
            secondWord := mload(add(data, 0xa0))
            secondLength := mload(add(data, 0xc0))
            secondsPerLiquidity0 := mload(add(data, 0xe0))
            secondsPerLiquidity1 := mload(add(data, 0x100))
        }
        if (
            firstOffset != 64 || secondOffset != 160 || firstLength != 2 || secondLength != 2
                || firstWord < int256(type(int56).min) || firstWord > int256(type(int56).max)
                || secondWord < int256(type(int56).min) || secondWord > int256(type(int56).max)
                || secondsPerLiquidity0 > type(uint160).max || secondsPerLiquidity1 > type(uint160).max
        ) revert OracleUnreadable(ethUsdgPool);
        return (int56(firstWord), int56(secondWord));
    }

    function _readSqrtPrice() private view returns (uint160 sqrtPriceX96) {
        sqrtPriceX96 = uint160(uint256(_readPoolWord(spotStorageSlot)));
        if (sqrtPriceX96 == 0) revert OracleUnreadable(poolManager);
    }

    function _readPoolWord(bytes32 slot) private view returns (bytes32 word) {
        (bool ok, bytes memory data) = poolManager.staticcall(abi.encodeWithSelector(IPons.extsload.selector, slot));
        if (!ok || data.length < 32) revert OracleUnreadable(poolManager);
        assembly ("memory-safe") {
            word := mload(add(data, 0x20))
        }
    }

    function _scaledSquare(uint160 value, uint256 scale) private pure returns (uint256) {
        uint256 whole = Math.mulDiv(uint256(value), uint256(value), Q192);
        uint256 remainder = mulmod(uint256(value), uint256(value), Q192);
        return whole * scale + Math.mulDiv(remainder, scale, Q192);
    }
}
