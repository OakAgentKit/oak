// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";

import {OakBurner} from "../src/OakBurner.sol";
import {OakOracle} from "../src/OakOracle.sol";

import {OakSubscription} from "../src/OakSubscription.sol";

/// @notice Operator-controlled deployment script. Simulation is the default; pass --broadcast separately.
contract DeploySubscription is Script {
    uint256 private constant MAINNET_CHAIN_ID = 4663;
    uint256 private constant TESTNET_CHAIN_ID = 46630;
    address private constant MAINNET_USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;

    error TokenMismatch(address source, address actual);

    error UnsupportedChain(uint256 chainId);
    error InvalidMainnetUsdg(address supplied);
    error PreviousHasNoCode(address previous);
    error PreviousNotRetired(address previous);

    function run() external returns (OakSubscription deployed) {
        if (block.chainid != MAINNET_CHAIN_ID && block.chainid != TESTNET_CHAIN_ID) {
            revert UnsupportedChain(block.chainid);
        }

        address usdg = vm.envAddress("OAK_USDG_ADDRESS");
        if (block.chainid == MAINNET_CHAIN_ID && usdg != MAINNET_USDG) {
            revert InvalidMainnetUsdg(usdg);
        }
        address oak = vm.envAddress("OAK_TOKEN_ADDRESS");
        address oracle = vm.envAddress("OAK_ORACLE_ADDRESS");
        address burner = vm.envAddress("OAK_BURNER_ADDRESS");
        address safe = vm.envAddress("OAK_SAFE_ADDRESS");
        address burnerToken = address(OakBurner(payable(burner)).oak());
        if (burnerToken != oak) revert TokenMismatch(burner, burnerToken);
        address oracleToken = OakOracle(oracle).oakToken();
        if (oracleToken != oak) revert TokenMismatch(oracle, oracleToken);

        address[] memory noRetiredSubscriptions = new address[](0);
        address[] memory retiredSubscriptions =
            vm.envOr("OAK_RETIRED_SUBSCRIPTION_ADDRESSES", ",", noRetiredSubscriptions);
        address previous = retiredSubscriptions.length == 0 ? address(0) : retiredSubscriptions[0];
        if (previous != address(0)) {
            if (previous.code.length == 0) revert PreviousHasNoCode(previous);
            try OakSubscription(previous).retired() returns (bool isRetired) {
                if (!isRetired) revert PreviousNotRetired(previous);
            } catch {
                revert PreviousNotRetired(previous);
            }
        }

        vm.startBroadcast();
        deployed = new OakSubscription(usdg, oak, oracle, burner, safe, safe, previous);
        vm.stopBroadcast();
    }
}
