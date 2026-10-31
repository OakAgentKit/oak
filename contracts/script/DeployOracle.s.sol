// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {OakOracle} from "../src/OakOracle.sol";
import {PonsRead} from "../src/interfaces/IPons.sol";

/// @notice Deploys OakOracle only on Robinhood Chain mainnet (4663) or testnet (46630), and only
///         against the public constants declared below. Every oracle address is
///         immutable, so a wrong environment value would otherwise cost a redeploy of every consumer.
contract DeployOracle is Script {
    struct Config {
        address ponsFactory;
        address oakToken;
        address poolManager;
        address ethUsdgPool;
        address safe;
        address priceSigner;
    }

    uint256 public constant MAINNET_CHAIN_ID = 4663;
    uint256 public constant TESTNET_CHAIN_ID = 46630;

    /// @dev Mainnet pins: Pons factory, pool manager and ETH/USDG pool.
    address public constant MAINNET_PONS_FACTORY = 0x7eD598BcEf8bd9Edd8C97A195C6d13f40801EC7e;
    address public constant MAINNET_POOL_MANAGER = 0x8366a39CC670B4001A1121B8F6A443A643e40951;
    address public constant MAINNET_ETH_USDG_POOL = 0x52e65B17fB6E5BA00Ed806f37Afcd2DaA50271Ca;
    address public constant PONS_HOOK = 0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044;

    /// @dev Testnet Uniswap v4 pool manager pin. Chain 46630 has no
    ///      pinned Pons factory or ETH/USDG pool (Pons V2 has no code there),
    ///      so the testnet profile requires deployed code at those two instead of an exact pin.
    address public constant TESTNET_POOL_MANAGER = 0x8366a39CC670B4001A1121B8F6A443A643e40951;

    error UnsupportedChain(uint256 chainId);
    error ZeroDeploymentAddress(string variableName);
    error UnpinnedAddress(string variableName, address expected, address actual);
    error MissingCode(string variableName, address account);
    error LaunchRecordUnreadable(address factory);
    error LaunchRecordMismatch(address expectedToken, address actualToken, bool exists);
    error PoolIdentityMismatch(address pairToken, uint24 poolFee, int24 tickSpacing, address hook);

    function run() external returns (OakOracle oracle) {
        oracle = deploy(
            Config({
                ponsFactory: vm.envAddress("OAK_PONS_FACTORY_ADDRESS"),
                oakToken: vm.envAddress("OAK_TOKEN_ADDRESS"),
                poolManager: vm.envAddress("OAK_POOL_MANAGER_ADDRESS"),
                ethUsdgPool: vm.envAddress("OAK_ETH_USDG_POOL_ADDRESS"),
                safe: vm.envAddress("OAK_SAFE_ADDRESS"),
                priceSigner: vm.envAddress("OAK_PRICE_SIGNER_ADDRESS")
            })
        );
    }

    function deploy(Config memory config) public returns (OakOracle oracle) {
        validate(config);
        vm.startBroadcast();
        oracle = new OakOracle(
            config.ponsFactory, config.oakToken, config.poolManager, config.ethUsdgPool, config.safe, config.priceSigner
        );
        vm.stopBroadcast();
    }

    function validate(Config memory config) public view {
        bool mainnet = block.chainid == MAINNET_CHAIN_ID;
        if (!mainnet && block.chainid != TESTNET_CHAIN_ID) revert UnsupportedChain(block.chainid);

        _requireNonZero("OAK_PONS_FACTORY_ADDRESS", config.ponsFactory);
        _requireNonZero("OAK_TOKEN_ADDRESS", config.oakToken);
        _requireNonZero("OAK_POOL_MANAGER_ADDRESS", config.poolManager);
        _requireNonZero("OAK_ETH_USDG_POOL_ADDRESS", config.ethUsdgPool);
        _requireNonZero("OAK_SAFE_ADDRESS", config.safe);
        _requireNonZero("OAK_PRICE_SIGNER_ADDRESS", config.priceSigner);

        if (mainnet) {
            _requirePinned("OAK_PONS_FACTORY_ADDRESS", MAINNET_PONS_FACTORY, config.ponsFactory);
            _requirePinned("OAK_POOL_MANAGER_ADDRESS", MAINNET_POOL_MANAGER, config.poolManager);
            _requirePinned("OAK_ETH_USDG_POOL_ADDRESS", MAINNET_ETH_USDG_POOL, config.ethUsdgPool);
        } else {
            _requirePinned("OAK_POOL_MANAGER_ADDRESS", TESTNET_POOL_MANAGER, config.poolManager);
            _requireCode("OAK_PONS_FACTORY_ADDRESS", config.ponsFactory);
            _requireCode("OAK_ETH_USDG_POOL_ADDRESS", config.ethUsdgPool);
        }
        _validatePoolIdentity(config.ponsFactory, config.oakToken);
    }

    function _requireNonZero(string memory variableName, address value) private pure {
        if (value == address(0)) revert ZeroDeploymentAddress(variableName);
    }

    function _requirePinned(string memory variableName, address expected, address actual) private pure {
        if (actual != expected) revert UnpinnedAddress(variableName, expected, actual);
    }

    function _requireCode(string memory variableName, address account) private view {
        if (account.code.length == 0) revert MissingCode(variableName, account);
    }

    function _validatePoolIdentity(address factory, address token) private view {
        (bool readable, address actualToken, address pairToken, uint24 poolFee, int24 tickSpacing,, bool exists) =
            PonsRead.launchRecordSummary(factory, token);
        if (!readable) revert LaunchRecordUnreadable(factory);
        if (!exists || actualToken != token) revert LaunchRecordMismatch(token, actualToken, exists);

        (bool hookReadable, address hook) = PonsRead.memeHook(factory);
        if (!hookReadable) revert LaunchRecordUnreadable(factory);
        if (pairToken != address(0) || poolFee != 0 || tickSpacing != 200 || hook != PONS_HOOK) {
            revert PoolIdentityMismatch(pairToken, poolFee, tickSpacing, hook);
        }
    }
}
