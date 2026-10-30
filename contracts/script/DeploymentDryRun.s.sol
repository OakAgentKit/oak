// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {DeployOracle} from "./DeployOracle.s.sol";
import {DeployBurner} from "./DeployBurner.s.sol";
import {DeploySubscription} from "./DeploySubscription.s.sol";

/// @notice Simulates the ordered mainnet deployment from the authoritative contract tree.
/// @dev Invoke without --broadcast. The live-sweep harness supplies public addresses only.
contract DeploymentDryRun is Script {
    function run() external {
        require(block.chainid == 4663, "Wrong chain");
        address oracle = address(new DeployOracle().run());
        vm.setEnv("OAK_ORACLE_ADDRESS", vm.toString(oracle));
        address burner = address(new DeployBurner().run());
        vm.setEnv("OAK_BURNER_ADDRESS", vm.toString(burner));
        new DeploySubscription().run();
    }
}
