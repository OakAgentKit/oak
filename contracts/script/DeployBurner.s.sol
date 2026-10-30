// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {OakBurner} from "../src/OakBurner.sol";

interface IBurnerDeploymentOracle {
    function oakToken() external view returns (address);
}

/// @notice Production-chain deployment script. Running without --broadcast is a simulation only.
contract DeployBurner is Script {
    uint256 internal constant ROBINHOOD_MAINNET_CHAIN_ID = 4663;
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    // OAK uses 18 decimals; deployment validates the token metadata.
    uint8 internal constant OAK_DECIMALS = 18;

    error WrongChain(uint256 actual);
    error TokenDecimalsMismatch(address token, uint8 expected, uint8 actual);
    error TokenMismatch(address source, address actual);

    function run() external returns (OakBurner burner) {
        address oak = vm.envAddress("OAK_TOKEN_ADDRESS");
        address oracle = vm.envAddress("OAK_ORACLE_ADDRESS");
        address safe = vm.envAddress("OAK_SAFE_ADDRESS");

        burner = deploy(oak, oracle, safe);
    }

    /// @notice Deploy after the oracle and before the subscription.
    /// @dev Token identity is checked here against the oracle. The successor
    ///      deployment step checks this burner's identity against the same token.
    ///      No placeholder subscription or predicted address is necessary.
    function deploy(address oak, address oracle, address safe) public returns (OakBurner burner) {
        if (block.chainid != ROBINHOOD_MAINNET_CHAIN_ID) revert WrongChain(block.chainid);

        _checkDecimals(oak, OAK_DECIMALS);
        _checkDecimals(USDG, 6);
        address oracleToken = IBurnerDeploymentOracle(oracle).oakToken();
        if (oracleToken != oak) revert TokenMismatch(oracle, oracleToken);
        // The burner must exist before the subscription can receive its final payees.
        // DeploySubscription checks this burner's token before deploying the consumer.

        vm.startBroadcast();
        burner = new OakBurner(USDG, oak, oracle, safe, OAK_DECIMALS);
        vm.stopBroadcast();
    }

    function _checkDecimals(address token, uint8 expected) internal view {
        uint8 actual = IERC20Metadata(token).decimals();
        if (actual != expected) revert TokenDecimalsMismatch(token, expected, actual);
    }
}
