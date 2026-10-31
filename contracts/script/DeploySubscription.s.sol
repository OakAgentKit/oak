// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";

import {OakBurner} from "../src/OakBurner.sol";
import {OakOracle} from "../src/OakOracle.sol";

import {OakSubscription} from "../src/OakSubscription.sol";

/// @notice Operator-controlled deployment script. Simulation is the default; pass --broadcast separately.
contract DeploySubscription is Script {
    struct Config {
        address usdg;
        address oak;
        address oracle;
        address burner;
        address safe;
        address previous;
    }

    uint256 private constant MAINNET_CHAIN_ID = 4663;
    uint256 private constant TESTNET_CHAIN_ID = 46630;
    address private constant MAINNET_USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;

    error TokenMismatch(address source, address actual);

    error UnsupportedChain(uint256 chainId);
    error InvalidMainnetUsdg(address supplied);
    error PreviousHasNoCode(address previous);
    error PreviousNotRetired(address previous);

    function run() external returns (OakSubscription deployed) {
        address[] memory noRetiredSubscriptions = new address[](0);
        address[] memory retiredSubscriptions =
            vm.envOr("OAK_RETIRED_SUBSCRIPTION_ADDRESSES", ",", noRetiredSubscriptions);
        deployed = deploy(
            Config({
                usdg: vm.envAddress("OAK_USDG_ADDRESS"),
                oak: vm.envAddress("OAK_TOKEN_ADDRESS"),
                oracle: vm.envAddress("OAK_ORACLE_ADDRESS"),
                burner: vm.envAddress("OAK_BURNER_ADDRESS"),
                safe: vm.envAddress("OAK_SAFE_ADDRESS"),
                previous: retiredSubscriptions.length == 0 ? address(0) : retiredSubscriptions[0]
            })
        );
    }

    function deploy(Config memory config) public returns (OakSubscription deployed) {
        if (block.chainid != MAINNET_CHAIN_ID && block.chainid != TESTNET_CHAIN_ID) {
            revert UnsupportedChain(block.chainid);
        }

        if (block.chainid == MAINNET_CHAIN_ID && config.usdg != MAINNET_USDG) {
            revert InvalidMainnetUsdg(config.usdg);
        }
        address burnerToken = address(OakBurner(payable(config.burner)).oak());
        if (burnerToken != config.oak) revert TokenMismatch(config.burner, burnerToken);
        address oracleToken = OakOracle(config.oracle).oakToken();
        if (oracleToken != config.oak) revert TokenMismatch(config.oracle, oracleToken);

        if (config.previous != address(0)) {
            if (config.previous.code.length == 0) revert PreviousHasNoCode(config.previous);
            try OakSubscription(config.previous).retired() returns (bool isRetired) {
                if (!isRetired) revert PreviousNotRetired(config.previous);
            } catch {
                revert PreviousNotRetired(config.previous);
            }
        }

        vm.startBroadcast();
        deployed = new OakSubscription(
            config.usdg, config.oak, config.oracle, config.burner, config.safe, config.safe, config.previous
        );
        vm.stopBroadcast();
    }
}
