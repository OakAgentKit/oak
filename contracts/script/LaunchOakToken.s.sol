// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";

interface IOakLaunchFactory {
    struct Metadata {
        string a;
        string b;
        string c;
        string d;
        string e;
    }

    struct Params {
        string name;
        string symbol;
        string description;
        string image;
        Metadata metadata;
        address creatorFeeRecipient;
        uint16 creatorTaxBps;
        bool buybackEnabled;
        bytes32 expectedEconomics;
        bytes32 salt;
    }

    struct Record {
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
    function launchFee() external view returns (uint256);
    function previewLaunchEconomics(uint256 config, address pair) external view returns (bytes32);
    function getLaunchedToken(address token) external view returns (Record memory);
    function transferCreatorFeeRecipient(address token, address recipient) external;
}

interface IOakLaunchRouter {
    function launchAndBuy(
        IOakLaunchFactory.Params calldata params,
        uint256 config,
        address pair,
        uint256 initialBuy,
        uint256 minTokens,
        address recipient,
        address[] calldata extra
    ) external payable returns (address token, address curve, uint256 tokensOut);
}

/// @notice Preparation is read-only. Execution is simulated unless the CLI explicitly broadcasts.
/// @dev The wrapper verifies Anvil for local rehearsals. Never pass a raw private key to this script.
contract LaunchOakToken is Script {
    address public constant FACTORY = 0x7eD598BcEf8bd9Edd8C97A195C6d13f40801EC7e;
    address public constant ROUTER = 0xe33E9E479dF8802cb0866d5d05258bEc4cF62948;
    bytes32 public constant ECONOMICS = 0xa9fc75d4203a33fe660e8fa32c74c3aa41c1fda4bf23d3a39b6bc22a1f8b1ca7;

    function prepare(IOakLaunchFactory.Params memory p, uint256 initialBuy, uint256 minimum, uint256 expectedFee)
        public
        view
        returns (bytes memory data, uint256 value)
    {
        require(block.chainid == 4663, "production launch profile only");
        require(FACTORY.code.length > 0 && ROUTER.code.length > 0, "missing Pons code");
        require(IOakLaunchRouter.launchAndBuy.selector == bytes4(0xf85f8e41), "launch ABI changed");
        require(p.creatorFeeRecipient != address(0), "missing launch recipient");
        require(p.creatorTaxBps == 100 && !p.buybackEnabled, "fee policy changed");
        require(initialBuy > 0 && minimum > 0, "initial buy and minimum required");
        bytes32 economics = IOakLaunchFactory(FACTORY).previewLaunchEconomics(0, address(0));
        require(economics == ECONOMICS && p.expectedEconomics == economics, "economics changed: review");
        uint256 fee = IOakLaunchFactory(FACTORY).launchFee();
        require(fee == expectedFee, "launch fee changed: review");
        data = abi.encodeCall(
            IOakLaunchRouter.launchAndBuy,
            (p, 0, address(0), initialBuy, minimum, p.creatorFeeRecipient, new address[](0))
        );
        value = fee + initialBuy;
    }

    /// @notice Exposes the exact run() calldata/value for receipt comparison without any transaction.
    function prepareFromEnvironment() public returns (bytes memory data, uint256 value) {
        address sender = vm.envAddress("OAK_DEPLOYER_ADDRESS");
        require(sender.code.length == 0, "launch sender must be codeless");
        IOakLaunchFactory.Params memory p = IOakLaunchFactory.Params({
            name: "Oak",
            symbol: "OAK",
            description: vm.envString("OAK_LAUNCH_DESCRIPTION"),
            image: vm.envString("OAK_LAUNCH_IMAGE"),
            metadata: IOakLaunchFactory.Metadata("", "", "", "", ""),
            creatorFeeRecipient: sender,
            creatorTaxBps: 100,
            buybackEnabled: false,
            salt: vm.envBytes32("OAK_LAUNCH_SALT"),
            expectedEconomics: ECONOMICS
        });
        return prepare(
            p,
            vm.envUint("OAK_INITIAL_BUY_WEI"),
            vm.envUint("OAK_MIN_TOKENS_OUT"),
            vm.envUint("OAK_EXPECTED_LAUNCH_FEE_WEI")
        );
    }

    function run() external returns (address token) {
        require(vm.envOr("OAK_OPERATOR_BROADCAST_APPROVED", false) || _local(), "operator flag or local Anvil required");
        address sender = vm.envAddress("OAK_DEPLOYER_ADDRESS");
        (bytes memory data, uint256 value) = prepareFromEnvironment();
        vm.startBroadcast(sender);
        (bool ok, bytes memory result) = ROUTER.call{value: value}(data);
        require(ok, "launch failed; inspect local receipt");
        (token,,) = abi.decode(result, (address, address, uint256));
        vm.stopBroadcast();
        IOakLaunchFactory.Record memory record = IOakLaunchFactory(FACTORY).getLaunchedToken(token);
        require(
            record.exists && record.creatorFeeRecipient == sender && record.pairToken == address(0)
                && record.creatorTaxBps == 100 && !record.buybackEnabled,
            "launch receipt/config mismatch"
        );
    }

    function _local() private returns (bool) {
        if (!vm.envOr("OAK_LOCAL_REHEARSAL", false)) return false;
        // An explicit local wrapper flag is insufficient by itself: check the selected RPC too.
        bytes memory client = vm.rpc("web3_clientVersion", "[]");
        return _contains(client, bytes("anvil"));
    }

    function _contains(bytes memory haystack, bytes memory needle) private pure returns (bool) {
        for (uint256 i; i + needle.length <= haystack.length; ++i) {
            bool matches = true;
            for (uint256 j; j < needle.length; ++j) {
                if (haystack[i + j] != needle[j]) matches = false;
            }
            if (matches) return true;
        }
        return false;
    }
}
