// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {OakOracle} from "../src/OakOracle.sol";
import {OakBurner} from "../src/OakBurner.sol";
import {OakSubscription} from "../src/OakSubscription.sol";
import {
    OakFixtureToken,
    OakFixtureFactory,
    OakFixturePoolManager,
    OakFixtureObservations,
    OakFixtureWeth,
    OakFixtureRoute,
    IOpsSafe
} from "../test/testnet/OakTestFixtures.sol";

/// @notice Separately approved stages for TEST ONLY fixtures and the actual Oak consumers on 46630.
/// @dev No production dependency is modified. The local route fixture cannot activate public-testnet burning.
contract DeployTestFixtures is Script {
    address public constant TEST_USDG = 0x7E955252E15c84f5768B83c41a71F9eba181802F;

    /// @notice One local simulation of all separately approved public stages; never a public entry path.
    function rehearse() external returns (address oracleAddress, address burnerAddress, address subscriptionAddress) {
        require(
            vm.envOr("OAK_LOCAL_REHEARSAL", false) && !vm.envOr("OAK_OPERATOR_BROADCAST_APPROVED", false),
            "local rehearsal only"
        );
        (
            OakFixtureToken token,
            OakFixtureFactory factory,
            OakFixturePoolManager manager,
            OakFixtureObservations observations
        ) = run();
        vm.setEnv("OAK_TOKEN_ADDRESS", vm.toString(address(token)));
        vm.setEnv("OAK_PONS_FACTORY_ADDRESS", vm.toString(address(factory)));
        vm.setEnv("OAK_POOL_MANAGER_ADDRESS", vm.toString(address(manager)));
        vm.setEnv("OAK_ETH_USDG_POOL_ADDRESS", vm.toString(address(observations)));
        oracleAddress = address(deployOracle());
        vm.setEnv("OAK_ORACLE_ADDRESS", vm.toString(oracleAddress));
        (OakBurner burner,,) = deployBurner();
        burnerAddress = address(burner);
        vm.setEnv("OAK_BURNER_ADDRESS", vm.toString(burnerAddress));
        subscriptionAddress = address(deploySubscription());
    }

    function run()
        public
        returns (
            OakFixtureToken token,
            OakFixtureFactory factory,
            OakFixturePoolManager manager,
            OakFixtureObservations observations
        )
    {
        address sender = _authorize();
        vm.startBroadcast(sender);
        token = new OakFixtureToken("TEST ONLY Oak", "testOAK", 18);
        factory = new OakFixtureFactory();
        manager = new OakFixturePoolManager();
        observations = new OakFixtureObservations();
        bytes32 id = keccak256(
            abi.encode(
                address(0), address(token), uint24(0), int24(200), address(0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044)
            )
        );
        bytes32 slot = keccak256(abi.encodePacked(id, uint256(6)));
        manager.set(slot, bytes32(uint256(112045541949572279837463876454916)));
        manager.set(bytes32(uint256(slot) + 3), bytes32(uint256(1e24)));
        vm.stopBroadcast();
    }

    function deployOracle() public returns (OakOracle oracle) {
        address sender = _authorize();
        address safe = _safe();
        address signer = vm.envAddress("OAK_PRICE_SIGNER_ADDRESS");
        require(signer != address(0) && signer != safe && signer.balance == 0, "invalid sign-only identity");
        address[] memory owners = IOpsSafe(safe).getOwners();
        for (uint256 i; i < owners.length; ++i) {
            require(signer != owners[i], "signer is Safe owner");
        }
        address factory = _code("OAK_PONS_FACTORY_ADDRESS");
        address token = _code("OAK_TOKEN_ADDRESS");
        address manager = _code("OAK_POOL_MANAGER_ADDRESS");
        address observations = _code("OAK_ETH_USDG_POOL_ADDRESS");
        vm.startBroadcast(sender);
        oracle = new OakOracle(factory, token, manager, observations, safe, signer);
        vm.stopBroadcast();
    }

    function deployBurner() public returns (OakBurner burner, OakFixtureWeth weth, OakFixtureRoute route) {
        address sender = _authorize();
        address safe = _safe();
        address token = _code("OAK_TOKEN_ADDRESS");
        OakOracle oracle = OakOracle(_code("OAK_ORACLE_ADDRESS"));
        require(oracle.safe() == safe && oracle.oakToken() == token, "oracle topology mismatch");
        vm.startBroadcast(sender);
        burner = new OakBurner(TEST_USDG, token, address(oracle), safe, 18);
        weth = new OakFixtureWeth();
        route = new OakFixtureRoute(oracle);
        vm.stopBroadcast();
        // WETH and route have arbitrary addresses. Only local vm.etch can substitute them at fixed pins.
    }

    function deploySubscription() public returns (OakSubscription subscription) {
        address sender = _authorize();
        address safe = _safe();
        address token = _code("OAK_TOKEN_ADDRESS");
        address oracle = _code("OAK_ORACLE_ADDRESS");
        address burner = _code("OAK_BURNER_ADDRESS");
        require(
            address(OakBurner(payable(burner)).oracle()) == oracle && OakBurner(payable(burner)).safe() == safe,
            "burner topology mismatch"
        );
        vm.startBroadcast(sender);
        subscription = new OakSubscription(TEST_USDG, token, oracle, burner, safe, safe, address(0));
        vm.stopBroadcast();
    }

    function _authorize() private returns (address sender) {
        require(block.chainid == 46630, "testnet fixtures only");
        require(TEST_USDG.code.length > 0, "real test USDG missing");
        if (!vm.envOr("OAK_OPERATOR_BROADCAST_APPROVED", false)) {
            require(vm.envOr("OAK_LOCAL_REHEARSAL", false), "operator flag or local Anvil required");
            bytes memory client = vm.rpc("web3_clientVersion", "[]");
            bool anvil;
            for (uint256 i; i + 5 <= client.length; ++i) {
                if (
                    keccak256(abi.encodePacked(client[i], client[i + 1], client[i + 2], client[i + 3], client[i + 4]))
                        == keccak256("anvil")
                ) anvil = true;
            }
            require(anvil, "local Anvil required");
        }
        sender = vm.envAddress("OAK_DEPLOYER_ADDRESS");
        require(sender.code.length == 0, "codeless deployer required");
    }

    function _safe() private view returns (address safe) {
        safe = _code("OAK_SAFE_ADDRESS");
        require(IOpsSafe(safe).getOwners().length == 3 && IOpsSafe(safe).getThreshold() == 2, "Safe must be 2 of 3");
        (address[] memory modules,) = IOpsSafe(safe).getModulesPaginated(address(1), 1);
        require(modules.length == 0, "Safe modules must be empty");
    }

    function _code(string memory variable) private view returns (address value) {
        value = vm.envAddress(variable);
        require(value.code.length > 0, "missing deployment code");
    }
}
