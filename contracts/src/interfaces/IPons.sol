// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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
