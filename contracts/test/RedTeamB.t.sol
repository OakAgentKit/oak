// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OakBurnerTest, DeployBurnerTest, MockUniversalRouter, MockToken} from "./OakBurner.t.sol";
import {OakOracleTest} from "./OakOracle.t.sol";
import {MockUSDG, MockOak} from "./OakSubscription.t.sol";
import {MockOracle} from "./mocks/MockOracle.sol";
import {OakBurner} from "../src/OakBurner.sol";
import {OakSubscription} from "../src/OakSubscription.sol";
import {IOakOracle} from "../src/interfaces/IOakOracle.sol";
import {IOakSubscription} from "../src/interfaces/IOakSubscription.sol";
import {IOakBurner} from "../src/interfaces/IOakBurner.sol";
import {IPons} from "../src/interfaces/IPons.sol";
import {OakPricing} from "../src/libraries/OakPricing.sol";
import {PriceNote, OakPriceNote} from "../src/libraries/OakPriceNote.sol";
import {DeploySubscription} from "../script/DeploySubscription.s.sol";
import {Test} from "forge-std/Test.sol";

contract RedTeamBBurnerTest is OakBurnerTest {
    function test_B_FeeMarginArithmetic() public pure {
        uint256 minimum = OakPricing.burnerMinOut(100_000_000, 2_000_000e18, 2_000e18, 18);
        assertLe(minimum, 97_000e18);
        assertGt(OakPricing.burnerMinOut(100_000_000, 2_060_000e18, 2_000e18, 18), 97_000e18);
    }

    function test_B_ZeroWalletNoteRefuses() public {
        (PriceNote memory n, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(0));
        vm.expectRevert(IOakOracle.NoteWrongWallet.selector);
        burner.buyAndBurn(1_000_000, n, sig);
    }

    function test_B_HonestFeeOutputBurns_ThreePercentHigherNoteRefuses() public {
        uint256 input = 100_000_000;
        // 1% hook + 2% creator tax: 97% output, before route impact.
        uint256 output = 97_000e18;
        MockUniversalRouter(payable(burnerRouter())).setAmountOut(output);
        (PriceNote memory bad, bytes memory badSig) = _signedNote(DEFAULT_OAK_PER_ETH * 103 / 100, address(this));
        vm.expectRevert();
        burner.buyAndBurn(input, bad, badSig);
        (PriceNote memory good, bytes memory goodSig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        uint256 supply = oak.totalSupply();
        burner.buyAndBurn(input, good, goodSig);
        assertEq(oak.totalSupply(), supply - output);
    }

    function test_B_CopiedKeeperNoteCannotDisarm_OriginalCallerCan() public {
        vm.prank(safe);
        burner.armSweep();
        (PriceNote memory n, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        vm.prank(makeAddr("copier"));
        vm.expectRevert(IOakOracle.NoteWrongWallet.selector);
        burner.buyAndBurn(1_000_000, n, sig);
        assertGt(burner.armedAt(), 0);
        burner.buyAndBurn(1_000_000, n, sig);
        assertEq(burner.armedAt(), 0);
        assertEq(burner.armedBalance(), 0);
        vm.expectRevert(IOakBurner.NoteUsed.selector);
        burner.buyAndBurn(1_000_000, n, sig);
    }

    function test_B_TwoKeepersShareNonce_OnlySameWalletReplayRefuses() public {
        (PriceNote memory n, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        burner.buyAndBurn(1_000_000, n, sig);
        n.wallet = makeAddr("second-keeper");
        sig = _sign(n, address(burner), SIGNER_PK);
        vm.prank(n.wallet);
        burner.buyAndBurn(1_000_000, n, sig);
        vm.prank(n.wallet);
        vm.expectRevert(IOakBurner.NoteUsed.selector);
        burner.buyAndBurn(1_000_000, n, sig);
    }
}

contract RedTeamBPhaseTest is OakOracleTest {
    function test_B_PhaseReadFailureShortUnknownRefuse_ValidCurveAndReadyWork() public {
        bytes memory callData = abi.encodeWithSelector(IPons.getLaunchedToken.selector, address(oak));
        vm.mockCallRevert(address(factory), callData, bytes("offline"));
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, address(factory)));
        oracle.phase();
        vm.clearMockedCalls();
        vm.mockCall(address(factory), callData, new bytes(10 * 32));
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, address(factory)));
        oracle.phase();
        vm.clearMockedCalls();
        factory.setPhase(3);
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, address(factory)));
        oracle.phase();
        factory.setPhase(0);
        assertEq(oracle.phase(), 0);
        factory.setPhase(1);
        assertEq(oracle.phase(), 0);
        factory.setPhase(2);
        assertEq(oracle.phase(), 1);
    }

    function test_B_SubscriptionLatchesReady_FactoryOutageCannotChargeFloor() public {
        MockUSDG usd = new MockUSDG();
        OakSubscription sub =
            new OakSubscription(address(usd), address(oak), address(oracle), address(3), address(4), SAFE, address(0));
        usd.mint(address(this), 1_000_000_000);
        usd.approve(address(sub), type(uint256).max);
        PriceNote memory n = _note(oracle.spotOakPerEthE18(), address(this), "subscription-latch");
        bytes memory sig = _sign(n, address(sub), SIGNER_KEY);
        sub.subscribe(2, 0, type(uint256).max, n, sig);
        factory.setPhase(0);
        assertEq(oracle.phase(), 1);
        PriceNote memory empty;
        vm.expectRevert(IOakOracle.NoteWrongWallet.selector);
        sub.quoteNoHold(empty, "");
        bytes memory callData = abi.encodeWithSelector(IPons.getLaunchedToken.selector, address(oak));
        vm.mockCallRevert(address(factory), callData, bytes("offline"));
        uint256 paid = sub.paidUntil(address(this));
        uint256 balance = usd.balanceOf(address(this));
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, address(factory)));
        sub.renewNoHold(type(uint256).max, empty, "");
        assertEq(sub.paidUntil(address(this)), paid);
        assertEq(usd.balanceOf(address(this)), balance);
    }

    function test_B_ReadyLatchSurvivesKnownRegression_UnknownStillRefuses() public {
        (bool ok,) = address(oracle).call(abi.encodeWithSignature("syncPhase()"));
        assertTrue(ok, "READY must be persisted by a transaction");
        factory.setPhase(0);
        assertEq(oracle.phase(), 1);
        factory.setPhase(1);
        assertEq(oracle.phase(), 1);
        factory.setPhase(3);
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, address(factory)));
        oracle.phase();
    }
}

contract RedTeamBSubscriptionTest is Test {
    function test_B_WalletNoncesIndependent_AllPaymentPathsRejectReplay() public {
        MockUSDG usd = new MockUSDG();
        MockOak token = new MockOak();
        MockOracle source = new MockOracle(address(1), address(2));
        source.setPhase(1);
        source.setEthUsdE18(2_000e18);
        source.setSpotOakPerEthE18(2_000_000e18);
        source.setSupplyNet(1_000_000e18);
        source.setPriceSigner(vm.addr(0xA11CE));
        OakSubscription sub = new OakSubscription(
            address(usd), address(token), address(source), address(3), address(4), address(5), address(0)
        );
        for (uint256 i = 1; i <= 3; ++i) {
            address wallet = address(uint160(100 + i));
            usd.mint(wallet, 100_000_000);
            token.mint(wallet, 100_000e18);
            PriceNote memory n = PriceNote(wallet, 2_000_000e18, uint64(block.timestamp), bytes32(uint256(7)));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xA11CE, OakPriceNote.digest(n, address(sub)));
            bytes memory sig = abi.encodePacked(r, s, v);
            vm.startPrank(wallet);
            usd.approve(address(sub), type(uint256).max);
            token.approve(address(sub), type(uint256).max);
            if (i == 1) {
                sub.subscribe(1, type(uint256).max, 0, n, sig);
            } else if (i == 2) {
                bytes memory auth = abi.encodeWithSignature(
                    "receiveWithAuthorization(address,address,uint256,uint256,uint256,bytes32,uint8,bytes32,bytes32)",
                    wallet,
                    address(sub),
                    uint256(9_000_000),
                    uint256(0),
                    type(uint256).max,
                    bytes32(uint256(9)),
                    uint8(27),
                    bytes32(0),
                    bytes32(0)
                );
                sub.subscribeWithAuthorization(type(uint256).max, n, sig, auth);
            } else {
                sub.subscribe(2, 0, type(uint256).max, n, sig);
                vm.expectRevert(IOakSubscription.NoteUsed.selector);
                sub.renewNoHold(type(uint256).max, n, sig);
            }
            sub.cancel();
            vm.expectRevert(IOakSubscription.NoteUsed.selector);
            sub.subscribe(1, type(uint256).max, 0, n, sig);
            vm.stopPrank();
        }
    }
}

contract RedTeamBDeploymentTest is DeployBurnerTest {
    function test_B_DeployOrderAndTokenGuards() public {
        OakBurner deployedBurner = deployer.deploy(address(oak), oracle, safe);
        DeploySubscription deploySub = new DeploySubscription();
        vm.setEnv("OAK_USDG_ADDRESS", vm.toString(USDG));
        vm.setEnv("OAK_TOKEN_ADDRESS", vm.toString(address(oak)));
        vm.setEnv("OAK_ORACLE_ADDRESS", vm.toString(oracle));
        vm.setEnv("OAK_BURNER_ADDRESS", vm.toString(address(deployedBurner)));
        vm.setEnv("OAK_SAFE_ADDRESS", vm.toString(safe));
        vm.setEnv("OAK_RETIRED_SUBSCRIPTION_ADDRESSES", "");
        OakSubscription deployed = deploySub.run();
        assertEq(deployed.burner(), address(deployedBurner));
        assertEq(address(deployed.oak()), address(oak));
        assertEq(address(deployed.oracle()), oracle);
        vm.mockCall(address(deployedBurner), abi.encodeWithSignature("oak()"), abi.encode(address(123)));
        vm.expectRevert(
            abi.encodeWithSelector(DeploySubscription.TokenMismatch.selector, address(deployedBurner), address(123))
        );
        deploySub.run();
        vm.mockCall(address(deployedBurner), abi.encodeWithSignature("oak()"), abi.encode(address(oak)));
        vm.mockCall(oracle, abi.encodeWithSignature("oakToken()"), abi.encode(address(123)));
        vm.expectRevert(abi.encodeWithSelector(DeploySubscription.TokenMismatch.selector, oracle, address(123)));
        deploySub.run();
        vm.mockCallRevert(oracle, abi.encodeWithSignature("oakToken()"), bytes("unreadable"));
        vm.expectRevert(bytes("unreadable"));
        deploySub.run();
        vm.mockCall(oracle, abi.encodeWithSignature("oakToken()"), abi.encode(address(oak)));
        vm.mockCall(address(deployedBurner), abi.encodeWithSignature("oak()"), hex"00");
        vm.expectRevert();
        deploySub.run();
    }
}
