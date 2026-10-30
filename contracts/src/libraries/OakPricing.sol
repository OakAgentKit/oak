// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice Shared, deterministic pricing arithmetic for Oak contracts and parity vectors.
library OakPricing {
    uint256 internal constant NOHOLD_FLOOR = 12_333_333;

    uint256 private constant USD_E18 = 1e18;
    uint256 private constant ENTRY_FLOOR = 20e18;
    uint256 private constant ENTRY_500K = 75e18;
    uint256 private constant ENTRY_1M = 100e18;
    uint256 private constant ENTRY_CAP = 300e18;
    uint256 private constant CAP_100K = 100_000e18;
    uint256 private constant CAP_500K = 500_000e18;
    uint256 private constant CAP_1M = 1_000_000e18;
    uint256 private constant CAP_10M = 10_000_000e18;

    error UnsupportedDecimals(uint8 decimals);

    /// @dev Continuous piecewise-linear entry price from $20 to $300, all values E18.
    function entryUsdE18(uint256 marketCap) internal pure returns (uint256) {
        if (marketCap < CAP_100K) return ENTRY_FLOOR;
        if (marketCap < CAP_500K) {
            return ENTRY_FLOOR + Math.mulDiv(marketCap - CAP_100K, ENTRY_500K - ENTRY_FLOOR, CAP_500K - CAP_100K);
        }
        if (marketCap < CAP_1M) {
            return ENTRY_500K + Math.mulDiv(marketCap - CAP_500K, ENTRY_1M - ENTRY_500K, CAP_1M - CAP_500K);
        }
        if (marketCap < CAP_10M) {
            return ENTRY_1M + Math.mulDiv(marketCap - CAP_1M, ENTRY_CAP - ENTRY_1M, CAP_10M - CAP_1M);
        }
        return ENTRY_CAP;
    }

    function noHoldPriceBase(uint256 entryE18) internal pure returns (uint256) {
        return 9_000_000 + (entryE18 / 1e12) / 6;
    }

    function splitBurn(uint256 amount) internal pure returns (uint256 burn, uint256 treasury) {
        burn = amount / 4;
        treasury = amount - burn;
    }

    function signupBurn(uint256 count) internal pure returns (uint256) {
        return Math.mulDiv(count, 5, 100, Math.Rounding.Ceil);
    }

    function oakUsdE18(uint256 ethUsdE18, uint256 oakPerEthE18) internal pure returns (uint256) {
        return Math.mulDiv(ethUsdE18, USD_E18, oakPerEthE18);
    }

    function requiredCount(uint256 entryE18, uint256 oakUsdE18_, uint8 oakDecimals) internal pure returns (uint256) {
        return Math.mulDiv(entryE18, _pow10(oakDecimals), oakUsdE18_, Math.Rounding.Ceil);
    }

    function marketCapUsdE18(uint256 supplyNet, uint256 oakUsdE18_, uint8 oakDecimals) internal pure returns (uint256) {
        return Math.mulDiv(supplyNet, oakUsdE18_, _pow10(oakDecimals));
    }

    function burnerMinOut(uint256 usdgIn, uint256 oakPerEthE18, uint256 ethUsdE18, uint8 oakDecimals)
        internal
        pure
        returns (uint256)
    {
        if (oakDecimals < 6) revert UnsupportedDecimals(oakDecimals);
        uint256 decimalScale = _pow10(oakDecimals - 6);
        // 49/51 = 96.0784%: accommodates hook/creator fees plus bounded route impact.
        return Math.mulDiv(usdgIn * decimalScale, oakPerEthE18 * 49, ethUsdE18 * 51);
    }

    function _pow10(uint8 decimals) private pure returns (uint256) {
        if (decimals > 77) revert UnsupportedDecimals(decimals);
        return 10 ** uint256(decimals);
    }
}
