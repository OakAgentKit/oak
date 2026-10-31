// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {OakOracle} from "../src/OakOracle.sol";
import {OakBurner} from "../src/OakBurner.sol";
import {OakPricing} from "../src/libraries/OakPricing.sol";
import {PriceNote, OakPriceNote} from "../src/libraries/OakPriceNote.sol";
import {IOakLaunchFactory, IOakLaunchRouter} from "../script/LaunchOakToken.s.sol";
import {IPons, PonsRead} from "../src/interfaces/IPons.sol";

interface IRedTeamCurve {
    function buy(uint256 quoteIn, uint256 minimum, address recipient) external payable returns (uint256);
}

interface IRedTeamHook {
    function owner() external view returns (address);
    function setHookFeeBps(uint256 feeBps) external;
    function currentFeePolicy() external view returns (address, uint256, uint256, uint256, uint256);
}

/// @dev Opt in with OAK_B_FORK_RPC_URL=https://rpc.mainnet.chain.robinhood.com.
/// No public signing or broadcast: all deployments and swaps execute in Forge's fork.
contract RedTeamBForkTest is Test {
    uint256 private constant BLOCK = 101_940_406;
    address private constant FACTORY = 0x7eD598BcEf8bd9Edd8C97A195C6d13f40801EC7e;
    address private constant ROUTER = 0xe33E9E479dF8802cb0866d5d05258bEc4cF62948;
    address private constant MANAGER = 0x8366a39CC670B4001A1121B8F6A443A643e40951;
    address private constant ETH_POOL = 0x52e65B17fB6E5BA00Ed806f37Afcd2DaA50271Ca;
    address private constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address private constant HOOK = 0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044;
    uint256 private constant SIGNER = 0xA11CE;

    function setUp() public {
        string memory rpc = vm.envOr("OAK_B_FORK_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        // Probe before switching forks: a pruned account read can abort the EVM
        // outside Solidity try/catch once the remote database is selected.
        try vm.rpc(rpc, "eth_getCode", '["0x7eD598BcEf8bd9Edd8C97A195C6d13f40801EC7e", "0x6137cb6"]') returns (
            bytes memory code
        ) {
            assertGt(code.length, 0, "factory code missing at pinned block");
        } catch {
            emit log_string("SKIP: RPC cannot serve pinned historical state");
            vm.skip(true);
            return;
        }
        try vm.createSelectFork(rpc, BLOCK) {}
        catch {
            emit log_string("SKIP: RPC cannot serve pinned block 101940406");
            vm.skip(true);
            return;
        }
        assertEq(block.chainid, 4663);
        assertEq(block.number, BLOCK);
        // Probe historical state separately: some RPCs serve the header but prune storage/code.
        try IOakLaunchFactory(FACTORY).launchFee() returns (uint256 fee) {
            assertGt(fee, 0);
        } catch {
            emit log_string("SKIP: RPC cannot serve pinned factory state");
            vm.skip(true);
        }
    }

    function testFork_B_ActualOakPolicyHonestNoteBurns_ThreePercentOffRefuses() public {
        _proveMargin(100);
    }

    function testFork_B_PacketTwoPercentCreatorTaxHonestNoteBurns_ThreePercentOffRefuses() public {
        _proveMargin(200);
    }

    function testFork_B_GlobalDefault1000DoesNotChangeGraduatedPoolFeeOrBlockBurn() public {
        _setGlobalHookFee(100);
        address token = _launchAndGraduate(100);
        bytes32 poolId = _poolId(token);
        assertEq(_poolHookFee(poolId), 100);

        _setGlobalHookFee(1_000);
        (,,, uint256 globalDefault,) = IRedTeamHook(HOOK).currentFeePolicy();
        assertEq(globalDefault, 1_000);
        assertEq(_poolHookFee(poolId), 100, "graduated pool fee changed with global default");

        assertGt(_honestBurn(token), 0, "pool-specific 100 bps floor should burn");
    }

    function testFork_B_ImplausibleGraduatedPoolFeeRevertsClearly() public {
        _setGlobalHookFee(751);
        address token = _launchAndGraduate(100);
        bytes32 poolId = _poolId(token);
        assertEq(_poolHookFee(poolId), 751);
        _setGlobalHookFee(100);
        assertEq(_poolHookFee(poolId), 751, "graduated pool fee followed global default");

        OakOracle oracle = new OakOracle(FACTORY, token, MANAGER, ETH_POOL, address(this), vm.addr(SIGNER));
        OakBurner burner = new OakBurner(USDG, token, address(oracle), address(this), 18);
        uint256 input = oracle.liquidityUsdgE6() / 4_000;
        deal(USDG, address(burner), input);
        uint256 spot = oracle.spotOakPerEthE18();
        PriceNote memory n = PriceNote(address(this), spot, uint64(block.timestamp), keccak256("implausible-pool-fee"));

        vm.expectRevert(abi.encodeWithSelector(OakPricing.FeePolicyOutOfBounds.selector, 751, 100));
        burner.buyAndBurn(input, n, _sign(n, address(burner)));
    }

    function _proveMargin(uint16 creatorTax) private {
        address token = _launchAndGraduate(creatorTax);
        OakOracle oracle = new OakOracle(FACTORY, token, MANAGER, ETH_POOL, address(this), vm.addr(SIGNER));
        OakBurner burner = new OakBurner(USDG, token, address(oracle), address(this), 18);
        uint256 spot = oracle.spotOakPerEthE18();
        uint256 ethUsd = oracle.ethUsdE18();
        uint256 input = oracle.liquidityUsdgE6() / 4000; // 0.025% of pool liquidity.
        assertGt(input, 0);
        deal(USDG, address(burner), input);
        PriceNote memory n = PriceNote(address(this), spot * 103 / 100, uint64(block.timestamp), keccak256("fee-note"));
        bytes memory sig = _sign(n, address(burner));
        uint256 supply = IERC20(token).totalSupply();
        uint256 snapshot = vm.snapshotState();
        vm.expectRevert();
        burner.buyAndBurn(input, n, sig);
        assertEq(IERC20(USDG).balanceOf(address(burner)), input);
        assertEq(IERC20(token).totalSupply(), supply);
        assertFalse(burner.noteUsed(n.wallet, n.nonce));
        assertTrue(vm.revertToState(snapshot));
        n.oakPerEthE18 = spot;
        sig = _sign(n, address(burner));
        burner.buyAndBurn(input, n, sig);
        uint256 burned = supply - IERC20(token).totalSupply();
        uint256 fair = Math.mulDiv(input * 1e12, spot, ethUsd);
        assertGt(burned, 0);
        uint256 feeAwareMinimum = OakPricing.burnerMinOut(input, spot, ethUsd, 18, OakPricing.MAX_BURNER_FLOOR_BPS);
        assertGe(burned, feeAwareMinimum);
        assertLe(feeAwareMinimum, Math.mulDiv(fair, 50, 51), "fee-aware floor exceeds old floor");
        assertEq(IERC20(USDG).balanceOf(address(burner)), 0);
        assertEq(IERC20(token).balanceOf(address(burner)), 0);
        assertTrue(burner.noteUsed(n.wallet, n.nonce));
        emit log_named_uint("creator tax bps", creatorTax);
        emit log_named_uint("USDG input", input);
        emit log_named_uint("fair output", fair);
        emit log_named_uint("actual OAK burned", burned);
        emit log_named_uint("output / fair in ppm", burned * 1_000_000 / fair);
        emit log_named_uint(
            "fee-aware minimum", OakPricing.burnerMinOut(input, spot, ethUsd, 18, OakPricing.MAX_BURNER_FLOOR_BPS)
        );
    }

    function _launchAndGraduate(uint16 tax) private returns (address token) {
        address launcher = makeAddr("red-team-B-launcher");
        assertEq(launcher.code.length, 0);
        assertEq(vm.getNonce(launcher), 0);
        vm.deal(launcher, 20 ether);
        IOakLaunchFactory.Params memory p = IOakLaunchFactory.Params({
            name: "Oak fee regression",
            symbol: "OAKTEST",
            description: "local fork only",
            image: "",
            metadata: IOakLaunchFactory.Metadata("", "", "", "", ""),
            creatorFeeRecipient: launcher,
            creatorTaxBps: tax,
            buybackEnabled: false,
            expectedEconomics: IOakLaunchFactory(FACTORY).previewLaunchEconomics(0, address(0)),
            salt: keccak256(abi.encode("red-team-B", tax))
        });
        uint256 fee = IOakLaunchFactory(FACTORY).launchFee();
        vm.startPrank(launcher, launcher);
        address curve;
        (token, curve,) = IOakLaunchRouter(ROUTER).launchAndBuy{value: fee + 0.1 ether}(
            p, 0, address(0), 0.1 ether, 1, launcher, new address[](0)
        );
        IRedTeamCurve(curve).buy{value: 6 ether}(6 ether, 1, launcher);
        IPons(FACTORY).createGraduatedPool(token);
        vm.stopPrank();
        IOakLaunchFactory.Record memory record = IOakLaunchFactory(FACTORY).getLaunchedToken(token);
        assertEq(record.phase, 2);
        assertEq(record.creatorTaxBps, tax);
        assertEq(record.pairToken, address(0));
        assertFalse(record.buybackEnabled);
    }

    function _setGlobalHookFee(uint256 feeBps) private {
        vm.prank(IRedTeamHook(HOOK).owner());
        IRedTeamHook(HOOK).setHookFeeBps(feeBps);
        (,,, uint256 current,) = IRedTeamHook(HOOK).currentFeePolicy();
        assertEq(current, feeBps);
    }

    function _poolId(address token) private pure returns (bytes32) {
        return keccak256(abi.encode(address(0), token, uint24(0), int24(200), HOOK));
    }

    function _poolHookFee(bytes32 poolId) private view returns (uint256 feeBps) {
        (bool readable, uint256 fee) = PonsRead.launchHookFeeBps(HOOK, poolId);
        assertTrue(readable, "graduated pool policy unreadable");
        return fee;
    }

    function _honestBurn(address token) private returns (uint256 burned) {
        OakOracle oracle = new OakOracle(FACTORY, token, MANAGER, ETH_POOL, address(this), vm.addr(SIGNER));
        OakBurner burner = new OakBurner(USDG, token, address(oracle), address(this), 18);
        uint256 input = oracle.liquidityUsdgE6() / 4_000;
        deal(USDG, address(burner), input);
        uint256 spot = oracle.spotOakPerEthE18();
        PriceNote memory n = PriceNote(address(this), spot, uint64(block.timestamp), keccak256("global-default"));
        uint256 supplyBefore = IERC20(token).totalSupply();
        burner.buyAndBurn(input, n, _sign(n, address(burner)));
        return supplyBefore - IERC20(token).totalSupply();
    }

    function _sign(PriceNote memory n, address consumer) private view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER, OakPriceNote.digest(n, consumer));
        return abi.encodePacked(r, s, v);
    }
}
