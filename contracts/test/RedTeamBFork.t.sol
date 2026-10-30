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
import {IPons} from "../src/interfaces/IPons.sol";

interface IRedTeamCurve {
    function buy(uint256 quoteIn, uint256 minimum, address recipient) external payable returns (uint256);
}

/// @dev Opt in with OAK_B_FORK_RPC_URL=https://rpc.mainnet.chain.robinhood.com.
/// No public signing or broadcast: all deployments and swaps execute in Forge's fork.
contract RedTeamBForkTest is Test {
    uint256 private constant BLOCK = 100_839_996;
    address private constant FACTORY = 0x7eD598BcEf8bd9Edd8C97A195C6d13f40801EC7e;
    address private constant ROUTER = 0xe33E9E479dF8802cb0866d5d05258bEc4cF62948;
    address private constant MANAGER = 0x8366a39CC670B4001A1121B8F6A443A643e40951;
    address private constant ETH_POOL = 0x52e65B17fB6E5BA00Ed806f37Afcd2DaA50271Ca;
    address private constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    uint256 private constant SIGNER = 0xA11CE;

    function setUp() public {
        string memory rpc = vm.envOr("OAK_B_FORK_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        // Probe before switching forks: a pruned account read can abort the EVM
        // outside Solidity try/catch once the remote database is selected.
        try vm.rpc(rpc, "eth_getCode", '["0x7eD598BcEf8bd9Edd8C97A195C6d13f40801EC7e", "0x602b23c"]') returns (
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
            emit log_string("SKIP: RPC cannot serve pinned block 100839996");
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
        assertGe(burned, OakPricing.burnerMinOut(input, spot, ethUsd, 18));
        assertLt(burned, Math.mulDiv(fair, 50, 51), "old margin must reject this honest route");
        assertEq(IERC20(USDG).balanceOf(address(burner)), 0);
        assertEq(IERC20(token).balanceOf(address(burner)), 0);
        assertTrue(burner.noteUsed(n.wallet, n.nonce));
        emit log_named_uint("creator tax bps", creatorTax);
        emit log_named_uint("USDG input", input);
        emit log_named_uint("fair output", fair);
        emit log_named_uint("actual OAK burned", burned);
        emit log_named_uint("output / fair in ppm", burned * 1_000_000 / fair);
        emit log_named_uint("49/51 minimum", OakPricing.burnerMinOut(input, spot, ethUsd, 18));
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

    function _sign(PriceNote memory n, address consumer) private view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER, OakPriceNote.digest(n, consumer));
        return abi.encodePacked(r, s, v);
    }
}
