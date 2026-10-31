// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

struct PonsLaunchRecord {
    address token;
    address curve;
    address deployer;
    address creatorFeeRecipient;
    address pairToken;
    uint256 graduationThreshold;
    uint24 poolFee;
    int24 tickSpacing;
    uint16 creatorTaxBps;
    bool buybackEnabled;
    uint8 phase;
    uint256 sweptQuote;
    uint256 sweptTokens;
    uint256 sweptAt;
    bool exists;
}

/// @notice Typed views used when Oak must validate the complete Pons launch record.
interface IPonsFactoryView {
    function getLaunchedToken(address token) external view returns (PonsLaunchRecord memory);
    function memeHook() external view returns (address);
}

/// @notice Selector-only view for the launch-frozen policy copied into a pool at graduation.
/// @dev The deployed hook returns a 13-word static record. Oak decodes only the
///      initialized flag (word 0) and hook fee (word 10) from the raw response.
interface IPonsHookView {
    function launches(bytes32 poolId) external view;
}

library PonsRead {
    function launchRecordSummary(address factory, address token)
        internal
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
        (bool ok, bytes memory data) =
            factory.staticcall(abi.encodeWithSelector(IPons.getLaunchedToken.selector, token));
        if (!ok || data.length < 15 * 32) return (false, address(0), address(0), 0, 0, 0, false);

        uint256 tokenWord;
        uint256 pairWord;
        uint256 feeWord;
        uint256 tickWord;
        uint256 taxWord;
        uint256 existsWord;
        assembly ("memory-safe") {
            tokenWord := mload(add(data, 0x20))
            pairWord := mload(add(data, 0xa0))
            feeWord := mload(add(data, 0xe0))
            tickWord := mload(add(data, 0x100))
            taxWord := mload(add(data, 0x120))
            existsWord := mload(add(data, 0x1e0))
        }
        int256 signedTick = int256(tickWord);
        if (
            tokenWord >> 160 != 0 || pairWord >> 160 != 0 || feeWord > type(uint24).max
                || signedTick < int256(type(int24).min) || signedTick > int256(type(int24).max)
                || taxWord > type(uint16).max || existsWord > 1
        ) return (false, address(0), address(0), 0, 0, 0, false);

        return (
            true,
            address(uint160(tokenWord)),
            address(uint160(pairWord)),
            uint24(feeWord),
            int24(signedTick),
            uint16(taxWord),
            existsWord == 1
        );
    }

    function memeHook(address factory) internal view returns (bool readable, address hook) {
        (bool ok, bytes memory data) = factory.staticcall(abi.encodeWithSelector(IPonsFactoryView.memeHook.selector));
        if (!ok || data.length < 32) return (false, address(0));
        uint256 hookWord;
        assembly ("memory-safe") {
            hookWord := mload(add(data, 0x20))
        }
        if (hookWord >> 160 != 0) return (false, address(0));
        return (true, address(uint160(hookWord)));
    }

    function launchHookFeeBps(address hook, bytes32 poolId) internal view returns (bool readable, uint256 feeBps) {
        (bool ok, bytes memory data) = hook.staticcall(abi.encodeWithSelector(IPonsHookView.launches.selector, poolId));
        if (!ok || data.length < 13 * 32) return (false, 0);
        uint256 initializedWord;
        assembly ("memory-safe") {
            initializedWord := mload(add(data, 0x20))
            feeBps := mload(add(data, 0x160))
        }
        if (initializedWord != 1) return (false, 0);
        return (true, feeBps);
    }
}

/// @notice Frozen selector catalog for the Pons surfaces consumed by Oak.
/// @dev getLaunchedToken intentionally declares no return tuple: the deployed record is wider than
///      Oak's phase-only use, so the oracle reads and validates the raw phase word without inventing
///      a partial ABI tuple. Extra return data is valid for this selector-only declaration.
interface IPons {
    function getLaunchedToken(address token) external view;
    function createGraduatedPool(address token) external;
    function transferCreatorFeeRecipient(address token, address newRecipient) external;
    function claim() external;
    function balanceOf(address account) external view returns (uint256);
    function sweepFees(uint256 amount) external;
    function sweepPoolFees(bytes32 poolId, uint256 amount0, uint256 amount1) external;
    function extsload(bytes32 slot) external view returns (bytes32 value);
}

library PonsSelectors {
    address internal constant LAUNCH_ROUTER = 0xe33E9E479dF8802cb0866d5d05258bEc4cF62948;
    bytes4 internal constant LAUNCH_AND_BUY = 0xf85f8e41;
    address internal constant UNIVERSAL_ROUTER_V2_1_2 = 0x204FAca1764B154221e35c0d20aBb3c525710498;
    bytes4 internal constant EXECUTE = 0x3593564c;
}
