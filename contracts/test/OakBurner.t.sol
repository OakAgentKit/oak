// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {DeployBurner} from "../script/DeployBurner.s.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {
    OakBurner,
    IBurnableERC20,
    ISwapRouter02,
    IUniversalRouter,
    IV3SwapRouter,
    PoolKey,
    V4ExactInputSingleParams
} from "../src/OakBurner.sol";
import {IOakOracle} from "../src/interfaces/IOakOracle.sol";
import {IOakBurner} from "../src/interfaces/IOakBurner.sol";
import {IPonsHookView, PonsLaunchRecord} from "../src/interfaces/IPons.sol";
import {OakPriceNote, PriceNote} from "../src/libraries/OakPriceNote.sol";
import {OakPricing} from "../src/libraries/OakPricing.sol";
import {MockOracle} from "./mocks/MockOracle.sol";

contract MockToken is IERC20, IBurnableERC20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;

    mapping(address account => uint256) public balanceOf;
    mapping(address owner => mapping(address spender => uint256)) public allowance;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function forceBurn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 permitted = allowance[from][msg.sender];
        if (permitted != type(uint256).max) {
            require(permitted >= amount, "allowance");
            allowance[from][msg.sender] = permitted - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "zero recipient");
        require(balanceOf[from] >= amount, "balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(balanceOf[from] >= amount, "burn balance");
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}

contract MockWeth is MockToken("Wrapped Ether", "WETH", 18) {
    receive() external payable {}

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "native transfer");
    }
}

contract MockSwapRouter02 is ISwapRouter02 {
    uint256 public amountOut;
    IV3SwapRouter.ExactInputSingleParams public lastParams;

    function setAmountOut(uint256 amountOut_) external {
        amountOut = amountOut_;
    }

    function exactInputSingle(IV3SwapRouter.ExactInputSingleParams calldata params) external payable returns (uint256) {
        lastParams = params;
        require(IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn), "pull");
        MockToken(params.tokenOut).mint(params.recipient, amountOut);
        return amountOut;
    }
}

contract MockUniversalRouter is IUniversalRouter {
    error TooLittleReceived(uint256 minimum, uint256 actual);

    uint256 public amountOut;
    bool public ignoreMinimum;
    bool public attemptReentry;
    bool public lastReentrySucceeded;
    bytes4 public lastReentryError;
    bytes public lastCommands;
    bytes public lastActions;
    PoolKey public lastPoolKey;
    bool public lastZeroForOne;
    uint128 public lastAmountIn;
    uint128 public lastAmountOutMinimum;
    uint256 public lastMinHopPriceX36;
    uint256 public lastHookDataLength;
    address public lastSettleCurrency;
    uint256 public lastSettleAmount;
    address public lastTakeCurrency;
    uint256 public lastTakeMinimum;

    function setAmountOut(uint256 amountOut_) external {
        amountOut = amountOut_;
    }

    function setIgnoreMinimum(bool ignoreMinimum_) external {
        ignoreMinimum = ignoreMinimum_;
    }

    function setAttemptReentry(bool attemptReentry_) external {
        attemptReentry = attemptReentry_;
    }

    function execute(bytes calldata commands, bytes[] calldata inputs, uint256) external payable {
        lastCommands = commands;
        (bytes memory actions, bytes[] memory params) = abi.decode(inputs[0], (bytes, bytes[]));
        lastActions = actions;

        V4ExactInputSingleParams memory swap = abi.decode(params[0], (V4ExactInputSingleParams));
        (address settleCurrency, uint256 settleAmount) = abi.decode(params[1], (address, uint256));
        (address takeCurrency, uint256 takeMinimum) = abi.decode(params[2], (address, uint256));

        lastPoolKey = swap.poolKey;
        lastZeroForOne = swap.zeroForOne;
        lastAmountIn = swap.amountIn;
        lastAmountOutMinimum = swap.amountOutMinimum;
        lastMinHopPriceX36 = swap.minHopPriceX36;
        lastHookDataLength = swap.hookData.length;
        lastSettleCurrency = settleCurrency;
        lastSettleAmount = settleAmount;
        lastTakeCurrency = takeCurrency;
        lastTakeMinimum = takeMinimum;

        require(commands.length == 1 && commands[0] == bytes1(uint8(0x10)), "commands");
        require(keccak256(actions) == keccak256(hex"060c0f"), "actions");
        require(settleCurrency == address(0) && settleAmount == msg.value, "settle");
        require(uint256(swap.amountIn) == msg.value, "value");

        if (attemptReentry) {
            bytes memory returnData;
            (lastReentrySucceeded, returnData) = msg.sender.call(abi.encodeCall(IOakBurner.armSweep, ()));
            if (returnData.length >= 4) {
                bytes4 selector;
                assembly ("memory-safe") {
                    selector := mload(add(returnData, 0x20))
                }
                lastReentryError = selector;
            }
        }

        uint256 minimum = uint256(swap.amountOutMinimum) > takeMinimum ? uint256(swap.amountOutMinimum) : takeMinimum;
        if (!ignoreMinimum && amountOut < minimum) revert TooLittleReceived(minimum, amountOut);
        require(IERC20(swap.poolKey.currency1).transfer(msg.sender, amountOut), "take");
    }
}

contract MockSubscriptionPayment {
    IERC20 public immutable usdg;
    address public immutable burner;
    address public immutable treasury;

    constructor(IERC20 usdg_, address burner_, address treasury_) {
        usdg = usdg_;
        burner = burner_;
        treasury = treasury_;
    }

    function pay(uint256 amount) external {
        uint256 burnShare = amount / 4;
        require(usdg.transferFrom(msg.sender, burner, burnShare), "burn share");
        require(usdg.transferFrom(msg.sender, treasury, amount - burnShare), "treasury share");
    }
}

contract MockPonsHook {
    uint256 internal defaultHookFeeBps;
    mapping(bytes32 poolId => uint256 feeBps) internal launchHookFeeBps;
    mapping(bytes32 poolId => bool initialized) internal launchInitialized;

    function setHookFeeBps(uint256 value) external {
        defaultHookFeeBps = value;
    }

    function setLaunch(bytes32 poolId, uint256 feeBps, bool initialized) external {
        launchHookFeeBps[poolId] = feeBps;
        launchInitialized[poolId] = initialized;
    }

    function currentFeePolicy() external view returns (address, uint256, uint256, uint256, uint256) {
        return (address(0xFEE), 3_000, 5_000, defaultHookFeeBps, 300);
    }

    function launches(bytes32 poolId) external view returns (uint256[13] memory words) {
        words[0] = launchInitialized[poolId] ? 1 : 0;
        words[10] = launchHookFeeBps[poolId];
    }
}

contract MockPonsLaunchRecords {
    PonsLaunchRecord internal record;

    function setRecord(address token, uint16 creatorTaxBps, bool exists) external {
        record.token = token;
        record.creatorTaxBps = creatorTaxBps;
        record.exists = exists;
    }

    function getLaunchedToken(address) external view returns (PonsLaunchRecord memory) {
        return record;
    }
}

abstract contract OakBurnerAssertions is Test {
    function _assertBurnedSupply(
        IERC20 token,
        address target,
        uint256 usdgIn,
        uint256 supplyBefore,
        Vm.Log[] memory logs
    ) internal view {
        uint256 burned;
        uint256 burnEvents;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == target && logs[i].topics.length > 0
                    && logs[i].topics[0] == keccak256("Burned(uint256,uint256)")
            ) {
                (uint256 spent, uint256 amount) = abi.decode(logs[i].data, (uint256, uint256));
                assertEq(spent, usdgIn);
                burned = amount;
                ++burnEvents;
            }
        }
        assertEq(burnEvents, 1);
        assertGt(burned, 0);
        assertEq(token.totalSupply(), supplyBefore - burned);
    }
}

contract OakBurnerTest is OakBurnerAssertions {
    uint256 internal constant SIGNER_PK = 0xA11CE;
    uint256 internal constant OTHER_SIGNER_PK = 0xB0B;
    uint256 internal constant DEFAULT_OAK_PER_ETH = 2_000_000e18;
    uint256 internal constant DEFAULT_ETH_USD = 2_000e18;
    uint256 internal constant DEFAULT_LIQUIDITY_USDG_E6 = 200_000_000_000;
    uint256 internal constant DEFAULT_V3_OUT = 1 ether;
    uint256 internal constant DEFAULT_OAK_OUT = 1_000_000e18;
    address internal constant PONS_FACTORY = 0x7eD598BcEf8bd9Edd8C97A195C6d13f40801EC7e;
    address internal constant PONS_HOOK = 0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044;

    address internal safe;
    address internal treasury;
    address internal signer;
    MockToken internal usdg;
    MockToken internal oak;
    MockOracle internal oracle;
    OakBurner internal burner;
    uint256 internal nonceCursor;

    function setUp() public {
        safe = makeAddr("safe");
        treasury = makeAddr("treasury");
        signer = vm.addr(SIGNER_PK);

        usdg = new MockToken("Global Dollar", "USDG", 6);
        oak = new MockToken("Oak", "OAK", 18);
        oak.mint(makeAddr("existing-oak-supply"), 1_000_000_000e18);
        oracle = new MockOracle(makeAddr("eth-usd-source"), makeAddr("spot-source"));
        oracle.setPhase(1);
        oracle.setEthUsdE18(DEFAULT_ETH_USD);
        oracle.setSpotOakPerEthE18(DEFAULT_OAK_PER_ETH);
        oracle.setLiquidityUsdgE6(DEFAULT_LIQUIDITY_USDG_E6);
        oracle.setPriceSigner(signer);

        _installRouteMocks();
        oak.mint(burnerRouter(), 1e33);
        burner = _newBurner(18);
        usdg.mint(address(burner), 10_000_000_000_000);
    }

    function test_ChunkExactlyHalfPercentAccepted_OneUnitAboveRejected() public {
        uint256[2] memory phaseLiquidity = [uint256(9_884_261_216), uint256(19_768_522_432)];

        for (uint256 i; i < phaseLiquidity.length; ++i) {
            oracle.setLiquidityUsdgE6(phaseLiquidity[i]);
            uint256 cap = phaseLiquidity[i] / 200;

            (PriceNote memory tooLarge, bytes memory tooLargeSig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
            vm.expectPartialRevert(OakBurner.ChunkTooLarge.selector);
            burner.buyAndBurn(cap + 1, tooLarge, tooLargeSig);

            (PriceNote memory exact, bytes memory exactSig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
            burner.buyAndBurn(cap, exact, exactSig);
            assertTrue(burner.noteUsed(exact.wallet, exact.nonce));
        }
    }

    function test_ConstructorRejectsZeroAddressesAndInvalidDecimals() public {
        vm.expectRevert(OakBurner.InvalidAddress.selector);
        new OakBurner(address(0), address(oak), address(oracle), safe, 18);
        vm.expectRevert(OakBurner.InvalidAddress.selector);
        new OakBurner(address(usdg), address(0), address(oracle), safe, 18);
        vm.expectRevert(OakBurner.InvalidAddress.selector);
        new OakBurner(address(usdg), address(oak), address(0), safe, 18);
        vm.expectRevert(OakBurner.InvalidAddress.selector);
        new OakBurner(address(usdg), address(oak), address(oracle), address(0), 18);

        vm.expectPartialRevert(OakBurner.InvalidOakDecimals.selector);
        new OakBurner(address(usdg), address(oak), address(oracle), safe, 5);
        vm.expectPartialRevert(OakBurner.InvalidOakDecimals.selector);
        new OakBurner(address(usdg), address(oak), address(oracle), safe, 78);
    }

    function test_UnexpectedNativeAndZeroInputRejected() public {
        vm.deal(address(this), 1);
        vm.expectRevert(OakBurner.UnexpectedNativeSender.selector);
        payable(address(burner)).transfer(1);

        PriceNote memory emptyNote;
        vm.expectRevert(OakBurner.ZeroAmount.selector);
        burner.buyAndBurn(0, emptyNote, bytes(""));
    }

    function test_ZeroFirstLegOutputRejected() public {
        MockSwapRouter02(burner.SWAP_ROUTER_02()).setAmountOut(0);
        (PriceNote memory note, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        vm.expectRevert(OakBurner.ZeroSwapOutput.selector);
        burner.buyAndBurn(1_000_000, note, sig);
        assertFalse(burner.noteUsed(note.wallet, note.nonce));
    }

    function test_RouterUint128OverflowRejected() public {
        MockSwapRouter02(burner.SWAP_ROUTER_02()).setAmountOut(uint256(type(uint128).max) + 1);
        (PriceNote memory note, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        vm.expectRevert(OakBurner.RouterAmountOverflow.selector);
        burner.buyAndBurn(1_000_000, note, sig);
        assertFalse(burner.noteUsed(note.wallet, note.nonce));
    }

    function test_MinimumUint128OverflowRejected() public {
        OakBurner highDecimals = _newBurner(77);
        usdg.mint(address(highDecimals), 1);
        (PriceNote memory note, bytes memory sig) =
            _signedNoteFor(highDecimals, DEFAULT_OAK_PER_ETH, address(this), SIGNER_PK);
        vm.expectRevert(OakBurner.RouterAmountOverflow.selector);
        highDecimals.buyAndBurn(1, note, sig);
        assertFalse(highDecimals.noteUsed(note.wallet, note.nonce));
    }

    function test_BurnerChecksOutputEvenIfRouterIgnoresMinimum() public {
        uint256 usdgIn = 1_000_000;
        uint256 minimum = OakPricing.burnerMinOut(
            usdgIn, DEFAULT_OAK_PER_ETH, DEFAULT_ETH_USD, 18, OakPricing.burnerFloorBps(100, 100)
        );
        MockUniversalRouter router = MockUniversalRouter(payable(burner.UNIVERSAL_ROUTER_V2_1_2()));
        router.setIgnoreMinimum(true);
        router.setAmountOut(minimum - 1);
        (PriceNote memory note, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));

        vm.expectPartialRevert(OakBurner.TooLittleOak.selector);
        burner.buyAndBurn(usdgIn, note, sig);
        assertFalse(burner.noteUsed(note.wallet, note.nonce));
    }

    function test_ReentrancyCallbackBlocked() public {
        MockUniversalRouter router = MockUniversalRouter(payable(burner.UNIVERSAL_ROUTER_V2_1_2()));
        router.setAttemptReentry(true);
        (PriceNote memory note, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        burner.buyAndBurn(1_000_000, note, sig);

        assertFalse(router.lastReentrySucceeded());
        assertEq(router.lastReentryError(), bytes4(keccak256("ReentrancyGuardReentrantCall()")));
        assertTrue(burner.noteUsed(note.wallet, note.nonce));
    }

    function test_MinOutUsesGraduationFeeFloor_VectorExact_At18Decimals() public {
        uint256 usdgIn = 100_000_000;
        (PriceNote memory note18, bytes memory sig18) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        burner.buyAndBurn(usdgIn, note18, sig18);
        assertEq(
            MockUniversalRouter(payable(burner.UNIVERSAL_ROUTER_V2_1_2())).lastAmountOutMinimum(),
            96_070_000_000_000_000_000_000
        );

        OakBurner sixDecimalBurner = _newBurner(6);
        usdg.mint(address(sixDecimalBurner), usdgIn);
        (PriceNote memory note6, bytes memory sig6) =
            _signedNoteFor(sixDecimalBurner, DEFAULT_OAK_PER_ETH, address(this), SIGNER_PK);
        MockUniversalRouter(payable(burner.UNIVERSAL_ROUTER_V2_1_2())).setAmountOut(DEFAULT_OAK_OUT);
        sixDecimalBurner.buyAndBurn(usdgIn, note6, sig6);
        assertEq(MockUniversalRouter(payable(burner.UNIVERSAL_ROUTER_V2_1_2())).lastAmountOutMinimum(), 96_070_000_000);
    }

    function test_RaisedGraduationFeeLowersFloorAndStillBurns() public {
        MockPonsHook(PONS_HOOK).setLaunch(_poolId(address(oak)), 350, true);
        uint256 usdgIn = 100_000_000;
        uint256 expectedMinimum = OakPricing.burnerMinOut(
            usdgIn, DEFAULT_OAK_PER_ETH, DEFAULT_ETH_USD, 18, OakPricing.burnerFloorBps(350, 100)
        );
        MockUniversalRouter(payable(burnerRouter())).setAmountOut(95_000e18);

        (PriceNote memory note, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        burner.buyAndBurn(usdgIn, note, sig);

        assertEq(expectedMinimum, 94_000e18);
        assertEq(MockUniversalRouter(payable(burnerRouter())).lastAmountOutMinimum(), expectedMinimum);
    }

    function test_GraduationFeeBeyondFloorBoundRevertsClearly() public {
        MockPonsHook(PONS_HOOK).setLaunch(_poolId(address(oak)), 751, true);
        (PriceNote memory note, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));

        vm.expectRevert(abi.encodeWithSelector(OakPricing.FeePolicyOutOfBounds.selector, 751, 100));
        burner.buyAndBurn(1_000_000, note, sig);
        assertFalse(burner.noteUsed(note.wallet, note.nonce));
    }

    function test_GlobalDefaultFeeDoesNotChangeGraduatedPoolFloor() public {
        MockPonsHook(PONS_HOOK).setHookFeeBps(1_000);
        uint256 usdgIn = 100_000_000;
        (PriceNote memory note, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));

        burner.buyAndBurn(usdgIn, note, sig);

        assertEq(
            MockUniversalRouter(payable(burnerRouter())).lastAmountOutMinimum(),
            OakPricing.burnerMinOut(
                usdgIn, DEFAULT_OAK_PER_ETH, DEFAULT_ETH_USD, 18, OakPricing.burnerFloorBps(100, 100)
            )
        );
    }

    function test_UnreadableGraduationFeePolicyRevertsClearly() public {
        vm.mockCallRevert(
            PONS_HOOK,
            abi.encodeWithSelector(IPonsHookView.launches.selector, _poolId(address(oak))),
            bytes("unreadable")
        );
        (PriceNote memory note, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));

        vm.expectRevert(abi.encodeWithSelector(OakBurner.FeePolicyUnreadable.selector, PONS_HOOK));
        burner.buyAndBurn(1_000_000, note, sig);
    }

    function test_MissingOrMismatchedLaunchRecordRevertsClearly() public {
        MockPonsLaunchRecords records = MockPonsLaunchRecords(PONS_FACTORY);
        records.setRecord(address(0), 100, false);
        (PriceNote memory missing, bytes memory missingSig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        vm.expectRevert(
            abi.encodeWithSelector(OakBurner.LaunchRecordMismatch.selector, address(oak), address(0), false)
        );
        burner.buyAndBurn(1_000_000, missing, missingSig);

        address wrongToken = makeAddr("wrong-launch-record-token");
        records.setRecord(wrongToken, 100, true);
        (PriceNote memory mismatch, bytes memory mismatchSig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        vm.expectRevert(abi.encodeWithSelector(OakBurner.LaunchRecordMismatch.selector, address(oak), wrongToken, true));
        burner.buyAndBurn(1_000_000, mismatch, mismatchSig);
    }

    function test_RevertsWorseThanLimit_WaitsDoesNotBrick_NonceNotConsumed() public {
        uint256 usdgIn = 100_000_000;
        uint256 minimum = OakPricing.burnerMinOut(
            usdgIn, DEFAULT_OAK_PER_ETH, DEFAULT_ETH_USD, 18, OakPricing.burnerFloorBps(100, 100)
        );
        (PriceNote memory note, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        uint256 balanceBefore = usdg.balanceOf(address(burner));

        MockUniversalRouter(payable(burner.UNIVERSAL_ROUTER_V2_1_2())).setAmountOut(minimum - 1);
        vm.expectPartialRevert(MockUniversalRouter.TooLittleReceived.selector);
        burner.buyAndBurn(usdgIn, note, sig);
        assertFalse(burner.noteUsed(note.wallet, note.nonce));
        assertEq(usdg.balanceOf(address(burner)), balanceBefore);

        MockUniversalRouter(payable(burner.UNIVERSAL_ROUTER_V2_1_2())).setAmountOut(minimum);
        burner.buyAndBurn(usdgIn, note, sig);
        assertTrue(burner.noteUsed(note.wallet, note.nonce));
    }

    function test_SubscriptionPaymentsUnaffectedByFailedBurn() public {
        MockSubscriptionPayment subscription = new MockSubscriptionPayment(usdg, address(burner), treasury);
        address subscriber = makeAddr("subscriber");
        uint256 payment = 9_000_000;
        usdg.mint(subscriber, payment * 2);
        vm.prank(subscriber);
        usdg.approve(address(subscription), payment * 2);

        vm.prank(subscriber);
        subscription.pay(payment);
        uint256 accumulatedBefore = usdg.balanceOf(address(burner));

        (PriceNote memory note, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        MockUniversalRouter(payable(burner.UNIVERSAL_ROUTER_V2_1_2())).setAmountOut(0);
        vm.expectPartialRevert(MockUniversalRouter.TooLittleReceived.selector);
        burner.buyAndBurn(payment / 4, note, sig);
        assertEq(usdg.balanceOf(address(burner)), accumulatedBefore);

        vm.prank(subscriber);
        subscription.pay(payment);
        assertEq(usdg.balanceOf(address(burner)), accumulatedBefore + payment / 4);
        assertEq(usdg.balanceOf(treasury), (payment - payment / 4) * 2);
    }

    function test_BurnReducesTotalSupply() public {
        uint256 supplyBefore = oak.totalSupply();
        (PriceNote memory note, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        vm.recordLogs();
        burner.buyAndBurn(100_000_000, note, sig);
        _assertBurnedSupply(oak, address(burner), 100_000_000, supplyBefore, vm.getRecordedLogs());
        assertEq(supplyBefore - oak.totalSupply(), DEFAULT_OAK_OUT);
        assertEq(oak.balanceOf(address(burner)), 0);
    }

    function test_RouteFixedUsdgEthOak() public {
        uint256 usdgIn = 100_000_000;
        (PriceNote memory note, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        burner.buyAndBurn(usdgIn, note, sig);

        MockSwapRouter02 v3 = MockSwapRouter02(burner.SWAP_ROUTER_02());
        (
            address tokenIn,
            address tokenOut,
            uint24 fee,
            address recipient,
            uint256 amountIn,
            uint256 amountOutMin,
            uint160 sqrtLimit
        ) = v3.lastParams();
        assertEq(tokenIn, address(usdg));
        assertEq(tokenOut, burner.WETH());
        assertEq(fee, 100);
        assertEq(recipient, address(burner));
        assertEq(amountIn, usdgIn);
        assertEq(amountOutMin, 0);
        assertEq(sqrtLimit, 0);

        MockUniversalRouter v4 = MockUniversalRouter(payable(burner.UNIVERSAL_ROUTER_V2_1_2()));
        (address currency0, address currency1, uint24 v4Fee, int24 tickSpacing, address hooks) = v4.lastPoolKey();
        assertEq(currency0, address(0));
        assertEq(currency1, address(oak));
        assertEq(v4Fee, 0);
        assertEq(tickSpacing, 200);
        assertEq(hooks, burner.PONS_HOOK());
        assertTrue(v4.lastZeroForOne());
        assertEq(v4.lastAmountIn(), DEFAULT_V3_OUT);
        assertEq(v4.lastMinHopPriceX36(), 0);
        assertEq(v4.lastHookDataLength(), 0);
        assertEq(v4.lastSettleCurrency(), address(0));
        assertEq(v4.lastSettleAmount(), DEFAULT_V3_OUT);
        assertEq(v4.lastTakeCurrency(), address(oak));
        assertEq(v4.lastTakeMinimum(), v4.lastAmountOutMinimum());
        assertEq(keccak256(v4.lastCommands()), keccak256(hex"10"));
        assertEq(keccak256(v4.lastActions()), keccak256(hex"060c0f"));
    }

    function test_NoteCallerWalletAndBurnerDomainRequired() public {
        (PriceNote memory subscriberNote, bytes memory subscriberSig) =
            _signedNote(DEFAULT_OAK_PER_ETH, makeAddr("subscriber-note-wallet"));
        vm.expectRevert(IOakOracle.NoteWrongWallet.selector);
        burner.buyAndBurn(1_000_000, subscriberNote, subscriberSig);

        PriceNote memory wrongDomain = _newNote(DEFAULT_OAK_PER_ETH, address(this));
        bytes memory wrongDomainSig = _sign(wrongDomain, makeAddr("other-consumer"), SIGNER_PK);
        vm.expectRevert(IOakOracle.NoteBadSignature.selector);
        burner.buyAndBurn(1_000_000, wrongDomain, wrongDomainSig);
    }

    function test_BurnerNonceSingleUse() public {
        (PriceNote memory note, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        burner.buyAndBurn(1_000_000, note, sig);
        vm.expectRevert(IOakBurner.NoteUsed.selector);
        burner.buyAndBurn(1_000_000, note, sig);
    }

    function test_BurnerSpotAgreementAcceptsNinePercentAndRejectsElevenPercent() public {
        uint256 spot = DEFAULT_OAK_PER_ETH;
        uint256 ninePercent = spot * 9 / 100;
        uint256 elevenPercent = spot * 11 / 100;

        (PriceNote memory highAccepted, bytes memory highAcceptedSig) = _signedNote(spot + ninePercent, address(this));
        burner.buyAndBurn(1_000_000, highAccepted, highAcceptedSig);

        (PriceNote memory highRejected, bytes memory highRejectedSig) = _signedNote(spot + elevenPercent, address(this));
        vm.expectRevert(abi.encodeWithSelector(OakBurner.NoteSpotMismatch.selector, spot, spot + elevenPercent));
        burner.buyAndBurn(1_000_000, highRejected, highRejectedSig);

        (PriceNote memory lowAccepted, bytes memory lowAcceptedSig) = _signedNote(spot - ninePercent, address(this));
        burner.buyAndBurn(1_000_000, lowAccepted, lowAcceptedSig);

        (PriceNote memory lowRejected, bytes memory lowRejectedSig) = _signedNote(spot - elevenPercent, address(this));
        vm.expectRevert(abi.encodeWithSelector(OakBurner.NoteSpotMismatch.selector, spot, spot - elevenPercent));
        burner.buyAndBurn(1_000_000, lowRejected, lowRejectedSig);
    }

    function test_BurnerSpotAgreementAcceptsExactTenPercent_RejectsOneUnitOutside() public {
        uint256 spot = oracle.spotOakPerEthE18();
        uint256 tolerance = spot / 10;
        MockUniversalRouter(payable(burnerRouter())).setAmountOut(DEFAULT_OAK_OUT * 2);

        (PriceNote memory exactHigh, bytes memory exactHighSig) = _signedNote(spot + tolerance, address(this));
        burner.buyAndBurn(1_000_000, exactHigh, exactHighSig);
        (PriceNote memory exactLow, bytes memory exactLowSig) = _signedNote(spot - tolerance, address(this));
        burner.buyAndBurn(1_000_000, exactLow, exactLowSig);

        (PriceNote memory highOutside, bytes memory highOutsideSig) = _signedNote(spot + tolerance + 1, address(this));
        vm.expectRevert(abi.encodeWithSelector(OakBurner.NoteSpotMismatch.selector, spot, spot + tolerance + 1));
        burner.buyAndBurn(1_000_000, highOutside, highOutsideSig);

        (PriceNote memory lowOutside, bytes memory lowOutsideSig) = _signedNote(spot - tolerance - 1, address(this));
        vm.expectRevert(abi.encodeWithSelector(OakBurner.NoteSpotMismatch.selector, spot, spot - tolerance - 1));
        burner.buyAndBurn(1_000_000, lowOutside, lowOutsideSig);
    }

    function test_SignerSwapOnOracleInvalidatesOldNotes_FreshAccepted() public {
        (PriceNote memory oldNote, bytes memory oldSig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        oracle.setPriceSigner(vm.addr(OTHER_SIGNER_PK));
        vm.expectRevert(IOakOracle.NoteBadSignature.selector);
        burner.buyAndBurn(1_000_000, oldNote, oldSig);

        (PriceNote memory freshNote, bytes memory freshSig) =
            _signedNoteFor(burner, DEFAULT_OAK_PER_ETH, address(this), OTHER_SIGNER_PK);
        burner.buyAndBurn(1_000_000, freshNote, freshSig);
    }

    function test_NoBurnBeforeReady_OrWhileEthUsdUnreadable_UsdgAccumulates() public {
        uint256 balanceBefore = usdg.balanceOf(address(burner));
        oracle.setPhase(0);
        (PriceNote memory notReady, bytes memory notReadySig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        vm.expectRevert(IOakOracle.NotReady.selector);
        burner.buyAndBurn(1_000_000, notReady, notReadySig);
        assertFalse(burner.noteUsed(notReady.wallet, notReady.nonce));
        assertEq(usdg.balanceOf(address(burner)), balanceBefore);

        oracle.setPhase(1);
        oracle.setSourceUnreadable(oracle.ethUsdSource(), true);
        (PriceNote memory unreadable, bytes memory unreadableSig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        vm.expectPartialRevert(IOakOracle.OracleUnreadable.selector);
        burner.buyAndBurn(1_000_000, unreadable, unreadableSig);
        assertFalse(burner.noteUsed(unreadable.wallet, unreadable.nonce));
        assertEq(usdg.balanceOf(address(burner)), balanceBefore);

        usdg.mint(address(burner), 2_250_000);
        assertEq(usdg.balanceOf(address(burner)), balanceBefore + 2_250_000);
    }

    function test_LaggingNoteAfterLargeMoveRejectedBeforeSwap() public {
        uint256 usdgIn = 100_000_000;
        oracle.setLiquidityUsdgE6(usdgIn * 200);
        uint256 lowerGuardNote = DEFAULT_OAK_PER_ETH / 2;
        uint256 balanceBefore = usdg.balanceOf(address(burner));

        (PriceNote memory note, bytes memory sig) = _signedNote(lowerGuardNote, address(this));
        vm.expectRevert(
            abi.encodeWithSelector(OakBurner.NoteSpotMismatch.selector, DEFAULT_OAK_PER_ETH, lowerGuardNote)
        );
        burner.buyAndBurn(usdgIn, note, sig);

        assertFalse(burner.noteUsed(note.wallet, note.nonce));
        assertEq(usdg.balanceOf(address(burner)), balanceBefore);
        assertEq(MockUniversalRouter(payable(burner.UNIVERSAL_ROUTER_V2_1_2())).lastAmountIn(), 0);
    }

    function test_ArmOnlySafe_RequiresBalance_RecordsBalance_ArmTwiceReverts() public {
        OakBurner emptyBurner = _newBurner(18);
        vm.prank(safe);
        vm.expectRevert(OakBurner.NoBalance.selector);
        emptyBurner.armSweep();

        usdg.mint(address(emptyBurner), 100);
        vm.expectRevert(OakBurner.OnlySafe.selector);
        emptyBurner.armSweep();

        vm.prank(safe);
        emptyBurner.armSweep();
        assertEq(emptyBurner.armedAt(), block.timestamp);
        assertEq(emptyBurner.armedBalance(), 100);

        vm.prank(safe);
        vm.expectRevert(OakBurner.AlreadyArmed.selector);
        emptyBurner.armSweep();
    }

    function test_SweepBeforeArmReverts() public {
        vm.prank(safe);
        vm.expectRevert(OakBurner.NotArmed.selector);
        burner.sweepStuck();
    }

    function test_SweepOnlySafe() public {
        vm.expectRevert(OakBurner.OnlySafe.selector);
        burner.sweepStuck();
    }

    function test_Sweep90DaysMinusOneSecondReverts_Exactly90Succeeds() public {
        OakBurner target = _newBurner(18);
        usdg.mint(address(target), 100);
        vm.prank(safe);
        target.armSweep();
        uint256 armed = block.timestamp;

        vm.warp(armed + 90 days - 1);
        vm.prank(safe);
        vm.expectPartialRevert(OakBurner.SweepNotReady.selector);
        target.sweepStuck();

        vm.warp(armed + 90 days);
        vm.prank(safe);
        target.sweepStuck();
        assertEq(usdg.balanceOf(safe), 100);
        assertEq(target.armedAt(), 0);
        assertEq(target.armedBalance(), 0);
    }

    function test_LastBurnAtTracksOnlySuccessfulBurns() public {
        assertEq(burner.lastBurnAt(), 0);
        vm.warp(block.timestamp + 1 days);
        (PriceNote memory first, bytes memory firstSig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        burner.buyAndBurn(1_000_000, first, firstSig);
        uint64 firstAt = uint64(block.timestamp);
        assertEq(burner.lastBurnAt(), firstAt);

        vm.warp(block.timestamp + 1 days);
        MockUniversalRouter(payable(burnerRouter())).setAmountOut(0);
        (PriceNote memory failed, bytes memory failedSig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        vm.expectPartialRevert(MockUniversalRouter.TooLittleReceived.selector);
        burner.buyAndBurn(1_000_000, failed, failedSig);
        assertEq(burner.lastBurnAt(), firstAt);

        MockUniversalRouter(payable(burnerRouter())).setAmountOut(DEFAULT_OAK_OUT);
        (PriceNote memory next, bytes memory nextSig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        burner.buyAndBurn(1_000_000, next, nextSig);
        assertEq(burner.lastBurnAt(), block.timestamp);
    }

    function test_OneBaseUnitBurnDoesNotDisarmSweep() public {
        OakBurner target = _newBurner(18);
        usdg.mint(address(target), 100_000_000);
        vm.prank(safe);
        target.armSweep();
        uint64 armedAt = target.armedAt();
        (PriceNote memory note, bytes memory sig) =
            _signedNoteFor(target, DEFAULT_OAK_PER_ETH, address(this), SIGNER_PK);
        target.buyAndBurn(1, note, sig);

        assertEq(target.armedAt(), armedAt);
        assertEq(target.armedBalance(), 100_000_000);
    }

    function test_MaterialBurnBelowOnePercentDoesNotDisarmSweep() public {
        OakBurner target = _newBurner(18);
        usdg.mint(address(target), 100_000_000);
        vm.prank(safe);
        target.armSweep();
        uint64 armedAt = target.armedAt();
        (PriceNote memory note, bytes memory sig) =
            _signedNoteFor(target, DEFAULT_OAK_PER_ETH, address(this), SIGNER_PK);
        target.buyAndBurn(500_000, note, sig);

        assertEq(target.armedAt(), armedAt);
        assertEq(target.armedBalance(), 100_000_000);
    }

    function test_NonMultipleArmedBalanceRoundsDisarmThresholdUp() public {
        OakBurner target = _newBurner(18);
        usdg.mint(address(target), 101);
        vm.prank(safe);
        target.armSweep();
        uint64 armedAt = target.armedAt();

        (PriceNote memory below, bytes memory belowSig) =
            _signedNoteFor(target, DEFAULT_OAK_PER_ETH, address(this), SIGNER_PK);
        target.buyAndBurn(1, below, belowSig);
        assertEq(target.armedAt(), armedAt);

        (PriceNote memory exact, bytes memory exactSig) =
            _signedNoteFor(target, DEFAULT_OAK_PER_ETH, address(this), SIGNER_PK);
        target.buyAndBurn(2, exact, exactSig);
        assertEq(target.armedAt(), 0);
        assertEq(target.armedBalance(), 0);
    }

    function test_OnePercentBurnDisarmsSweep() public {
        OakBurner target = _newBurner(18);
        usdg.mint(address(target), 100_000_000);
        vm.prank(safe);
        target.armSweep();
        (PriceNote memory note, bytes memory sig) =
            _signedNoteFor(target, DEFAULT_OAK_PER_ETH, address(this), SIGNER_PK);
        target.buyAndBurn(1_000_000, note, sig);
        assertEq(target.armedAt(), 0);
        assertEq(target.armedBalance(), 0);

        vm.warp(block.timestamp + 90 days);
        vm.prank(safe);
        vm.expectRevert(OakBurner.NotArmed.selector);
        target.sweepStuck();
    }

    function test_ChunkCapIsAttainableDisarmThresholdWhenOnePercentIsLarger() public {
        uint256 maximum = 1_000_000;
        oracle.setLiquidityUsdgE6(maximum * 200);
        OakBurner target = _newBurner(18);
        usdg.mint(address(target), maximum * 200);
        vm.prank(safe);
        target.armSweep();
        uint64 armedAt = target.armedAt();

        (PriceNote memory below, bytes memory belowSig) =
            _signedNoteFor(target, DEFAULT_OAK_PER_ETH, address(this), SIGNER_PK);
        target.buyAndBurn(maximum - 1, below, belowSig);
        assertEq(target.armedAt(), armedAt);

        (PriceNote memory exact, bytes memory exactSig) =
            _signedNoteFor(target, DEFAULT_OAK_PER_ETH, address(this), SIGNER_PK);
        target.buyAndBurn(maximum, exact, exactSig);
        assertEq(target.armedAt(), 0);
        assertEq(target.armedBalance(), 0);
    }

    function test_FailedBurnDoesNotDisarm() public {
        vm.prank(safe);
        burner.armSweep();
        uint64 armedAt = burner.armedAt();
        uint256 armedBalance = burner.armedBalance();
        (PriceNote memory note, bytes memory sig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        MockUniversalRouter(payable(burner.UNIVERSAL_ROUTER_V2_1_2())).setAmountOut(0);

        vm.expectPartialRevert(MockUniversalRouter.TooLittleReceived.selector);
        burner.buyAndBurn(1_000_000, note, sig);
        assertEq(burner.armedAt(), armedAt);
        assertEq(burner.armedBalance(), armedBalance);
    }

    function test_DepositAfterArmNotSwept_NeedsFreshArm() public {
        OakBurner target = _newBurner(18);
        usdg.mint(address(target), 100);
        vm.prank(safe);
        target.armSweep();
        usdg.mint(address(target), 50);

        vm.warp(block.timestamp + 90 days);
        vm.prank(safe);
        target.sweepStuck();
        assertEq(usdg.balanceOf(safe), 100);
        assertEq(usdg.balanceOf(address(target)), 50);
        assertEq(target.armedAt(), 0);

        vm.prank(safe);
        vm.expectRevert(OakBurner.NotArmed.selector);
        target.sweepStuck();
        vm.prank(safe);
        target.armSweep();
        assertEq(target.armedBalance(), 50);
    }

    function test_SweepMovesMinOfBalanceAndArmed() public {
        OakBurner target = _newBurner(18);
        usdg.mint(address(target), 100);
        vm.prank(safe);
        target.armSweep();
        usdg.forceBurn(address(target), 40);

        vm.warp(block.timestamp + 90 days);
        vm.prank(safe);
        target.sweepStuck();
        assertEq(usdg.balanceOf(safe), 60);
        assertEq(usdg.balanceOf(address(target)), 0);
    }

    function test_AbiHasNoSignerSetterOrTick() public {
        (bool signerSetter,) = address(burner).call(abi.encodeWithSignature("setPriceSigner(address)", address(this)));
        (bool tick,) = address(burner).call(abi.encodeWithSignature("tick()"));
        assertFalse(signerSetter);
        assertFalse(tick);
    }

    function testFuzz_ChunkBoundaryMatchesHalfPercent(uint64 liquiditySeed) public {
        uint256 liquidity = bound(uint256(liquiditySeed), 200, 1_000_000_000_000);
        oracle.setLiquidityUsdgE6(liquidity);
        uint256 cap = liquidity / 200;
        MockUniversalRouter(payable(burner.UNIVERSAL_ROUTER_V2_1_2())).setAmountOut(1e30);

        (PriceNote memory tooLarge, bytes memory tooLargeSig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        vm.expectPartialRevert(OakBurner.ChunkTooLarge.selector);
        burner.buyAndBurn(cap + 1, tooLarge, tooLargeSig);

        (PriceNote memory exact, bytes memory exactSig) = _signedNote(DEFAULT_OAK_PER_ETH, address(this));
        burner.buyAndBurn(cap, exact, exactSig);
        assertTrue(burner.noteUsed(exact.wallet, exact.nonce));
    }

    function testFuzz_SweepNeverIncludesPostArmDeposit(uint96 armedSeed, uint96 laterSeed) public {
        uint256 armed = bound(uint256(armedSeed), 1, type(uint96).max);
        uint256 later = uint256(laterSeed);
        OakBurner target = _newBurner(18);
        usdg.mint(address(target), armed);
        vm.prank(safe);
        target.armSweep();
        usdg.mint(address(target), later);

        vm.warp(block.timestamp + 90 days);
        vm.prank(safe);
        target.sweepStuck();
        assertEq(usdg.balanceOf(safe), armed);
        assertEq(usdg.balanceOf(address(target)), later);
    }

    function _installRouteMocks() internal {
        MockWeth wethImplementation = new MockWeth();
        MockSwapRouter02 v3Implementation = new MockSwapRouter02();
        MockUniversalRouter v4Implementation = new MockUniversalRouter();
        MockPonsHook feePolicyImplementation = new MockPonsHook();
        MockPonsLaunchRecords launchRecordsImplementation = new MockPonsLaunchRecords();
        vm.etch(0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73, address(wethImplementation).code);
        vm.etch(0xCaf681a66D020601342297493863E78C959E5cb2, address(v3Implementation).code);
        vm.etch(0x204FAca1764B154221e35c0d20aBb3c525710498, address(v4Implementation).code);
        vm.etch(PONS_HOOK, address(feePolicyImplementation).code);
        vm.etch(PONS_FACTORY, address(launchRecordsImplementation).code);
        vm.deal(0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73, 10_000 ether);
        MockSwapRouter02(0xCaf681a66D020601342297493863E78C959E5cb2).setAmountOut(DEFAULT_V3_OUT);
        MockUniversalRouter(payable(0x204FAca1764B154221e35c0d20aBb3c525710498)).setAmountOut(DEFAULT_OAK_OUT);
        MockPonsHook(PONS_HOOK).setHookFeeBps(100);
        MockPonsHook(PONS_HOOK).setLaunch(_poolId(address(oak)), 100, true);
        MockPonsLaunchRecords(PONS_FACTORY).setRecord(address(oak), 100, true);
    }

    function _poolId(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(address(0), token, uint24(0), int24(200), PONS_HOOK));
    }

    function burnerRouter() internal pure returns (address) {
        return 0x204FAca1764B154221e35c0d20aBb3c525710498;
    }

    function _newBurner(uint8 decimals_) internal returns (OakBurner) {
        return new OakBurner(address(usdg), address(oak), address(oracle), safe, decimals_);
    }

    function _newNote(uint256 oakPerEthE18, address wallet) internal returns (PriceNote memory) {
        return PriceNote({
            wallet: wallet,
            oakPerEthE18: oakPerEthE18,
            timestamp: uint64(block.timestamp),
            nonce: bytes32(++nonceCursor)
        });
    }

    function _signedNote(uint256 oakPerEthE18, address wallet)
        internal
        returns (PriceNote memory note, bytes memory signature)
    {
        return _signedNoteFor(burner, oakPerEthE18, wallet, SIGNER_PK);
    }

    function _signedNoteFor(OakBurner target, uint256 oakPerEthE18, address wallet, uint256 privateKey)
        internal
        returns (PriceNote memory note, bytes memory signature)
    {
        note = _newNote(oakPerEthE18, wallet);
        signature = _sign(note, address(target), privateKey);
    }

    function _sign(PriceNote memory note, address consumer, uint256 privateKey)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 digest = OakPriceNote.digest(note, consumer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        signature = abi.encodePacked(r, s, v);
    }
}

contract OakBurnerForkTest is OakBurnerAssertions {
    uint256 internal constant PINNED_FORK_BLOCK = 100_521_400;
    uint256 internal constant SIGNER_PK = 0xA11CE;
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address internal constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
    address internal constant OAK = 0xaF2d6cc1586539997840D4635480c2F8494DaC2e;
    address internal constant SWAP_ROUTER_02 = 0xCaf681a66D020601342297493863E78C959E5cb2;
    address internal constant UNIVERSAL_ROUTER = 0x204FAca1764B154221e35c0d20aBb3c525710498;
    address internal constant PONS_HOOK = 0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044;
    bytes32 internal constant SWAP_ROUTER_02_RUNTIME_SHA256 =
        0xa84426d2e34ef0d88f458c34993f1aef59617481f17891a74cfc15e6ee93c0cf;
    bytes32 internal constant UNIVERSAL_ROUTER_RUNTIME_SHA256 =
        0x181b1ac28443740bb07db7ed0bb908815dcf90435af0c9f45406bc1c89a80ac3;

    receive() external payable {}

    function testFork_RealV212BurnerRoute() public {
        _selectFork();
        address safe = makeAddr("fork-safe");
        MockOracle oracle = new MockOracle(makeAddr("fork-eth-source"), makeAddr("fork-spot-source"));
        oracle.setPhase(1);
        oracle.setEthUsdE18(3_000e18);
        oracle.setSpotOakPerEthE18(10_000_000e18);
        oracle.setLiquidityUsdgE6(2_000_000_000);
        oracle.setPriceSigner(vm.addr(SIGNER_PK));
        OakBurner target = new OakBurner(USDG, OAK, address(oracle), safe, 18);

        uint256 usdgIn = 1_000_000;
        deal(USDG, address(target), usdgIn);
        uint256 usdgBefore = IERC20(USDG).balanceOf(address(target));
        uint256 supplyBefore = IERC20(OAK).totalSupply();
        address caller = _freshAddress("fork-burn-caller");
        PriceNote memory note = PriceNote({
            wallet: caller,
            oakPerEthE18: 10_000_000e18,
            timestamp: uint64(block.timestamp),
            nonce: keccak256("fork-burn-note")
        });
        bytes memory signature = _sign(note, address(target));

        vm.recordLogs();
        vm.prank(caller);
        target.buyAndBurn(usdgIn, note, signature);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 supplyAfter = IERC20(OAK).totalSupply();
        assertEq(usdgBefore - IERC20(USDG).balanceOf(address(target)), usdgIn);
        _assertBurnedSupply(IERC20(OAK), address(target), usdgIn, supplyBefore, logs);
        assertEq(IERC20(OAK).balanceOf(address(target)), 0);
        assertEq(IERC20(WETH).balanceOf(address(target)), 0);
        assertEq(address(target).balance, 0);
        emit log_named_uint("fork block", block.number);
        emit log_named_address("SwapRouter02", target.SWAP_ROUTER_02());
        emit log_named_address("Universal Router v2.1.2", target.UNIVERSAL_ROUTER_V2_1_2());
        emit log_named_uint("USDG debited", usdgIn);
        emit log_named_uint("OAK burned", supplyBefore - supplyAfter);
    }

    function testFork_V212SixFieldMinOut() public {
        _selectFork();
        uint128 amountIn = 0.0001 ether;
        PoolKey memory key =
            PoolKey({currency0: address(0), currency1: OAK, fee: 0, tickSpacing: 200, hooks: PONS_HOOK});

        address positiveCaller = _freshAddress("six-field-positive");
        bytes memory sixField = abi.encode(
            V4ExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,
                amountIn: amountIn,
                amountOutMinimum: 1,
                minHopPriceX36: 0,
                hookData: bytes("")
            })
        );
        (bool positive,) = _callV4(positiveCaller, amountIn, sixField, 1);
        assertTrue(positive);
        assertGt(IERC20(OAK).balanceOf(positiveCaller), 0);
        assertEq(positiveCaller.balance, 0);

        address fiveFieldCaller = _freshAddress("five-field-control");
        bytes memory fiveField = abi.encode(key, true, amountIn, uint128(1), bytes(""));
        (bool fiveFieldAccepted,) = _callV4(fiveFieldCaller, amountIn, fiveField, 1);
        assertFalse(fiveFieldAccepted);
        assertEq(IERC20(OAK).balanceOf(fiveFieldCaller), 0);

        address excessiveCaller = _freshAddress("excessive-min-control");
        bytes memory excessiveMinimum = abi.encode(
            V4ExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,
                amountIn: amountIn,
                amountOutMinimum: type(uint128).max,
                minHopPriceX36: 0,
                hookData: bytes("")
            })
        );
        (bool excessiveAccepted,) = _callV4(excessiveCaller, amountIn, excessiveMinimum, type(uint128).max);
        assertFalse(excessiveAccepted);
        assertEq(IERC20(OAK).balanceOf(excessiveCaller), 0);
        emit log_named_uint("fork block", block.number);
        emit log_named_string("positive control", "six-field V4_SWAP executed");
        emit log_named_string("negative control", "legacy five-field tuple reverted");
        emit log_named_string("limit control", "excessive amountOutMinimum reverted");
    }

    function _callV4(address caller, uint128 amountIn, bytes memory swap, uint256 takeMinimum)
        internal
        returns (bool ok, bytes memory returnData)
    {
        bytes[] memory params = new bytes[](3);
        params[0] = swap;
        params[1] = abi.encode(address(0), uint256(amountIn));
        params[2] = abi.encode(OAK, takeMinimum);
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(hex"060c0f", params);
        bytes memory callData = abi.encodeCall(IUniversalRouter.execute, (hex"10", inputs, block.timestamp + 300));
        vm.deal(caller, amountIn);
        vm.prank(caller);
        (ok, returnData) = UNIVERSAL_ROUTER.call{value: amountIn}(callData);
    }

    function _selectFork() internal {
        string memory rpcUrl = vm.envOr("OAK_FORK_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) vm.skip(true);
        vm.createSelectFork(rpcUrl, PINNED_FORK_BLOCK);
        assertEq(block.number, PINNED_FORK_BLOCK);
        assertGt(UNIVERSAL_ROUTER.code.length, 0);
        assertGt(OAK.code.length, 0);
        assertEq(sha256(SWAP_ROUTER_02.code), SWAP_ROUTER_02_RUNTIME_SHA256);
        assertEq(sha256(UNIVERSAL_ROUTER.code), UNIVERSAL_ROUTER_RUNTIME_SHA256);
    }

    function _freshAddress(string memory label) internal view returns (address account) {
        account = address(uint160(uint256(keccak256(bytes(label)))));
        assertEq(account.code.length, 0);
        assertEq(vm.getNonce(account), 0);
    }

    function _sign(PriceNote memory note, address consumer) internal view returns (bytes memory signature) {
        bytes32 digest = OakPriceNote.digest(note, consumer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PK, digest);
        signature = abi.encodePacked(r, s, v);
    }
}

contract DeployBurnerTest is Test {
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    DeployBurner internal deployer;
    MockToken internal oak;
    address internal oracle;
    address internal subscription;
    address internal safe;

    function setUp() public {
        vm.chainId(4663);
        deployer = new DeployBurner();
        oak = new MockToken("Oak", "OAK", 18);
        oracle = makeAddr("deployment-oracle");
        subscription = makeAddr("deployment-subscription");
        safe = makeAddr("deployment-safe");
        MockToken usdg = new MockToken("Global Dollar", "USDG", 6);
        vm.etch(USDG, address(usdg).code);
        vm.mockCall(oracle, abi.encodeWithSignature("oakToken()"), abi.encode(address(oak)));
        vm.mockCall(subscription, abi.encodeWithSignature("oak()"), abi.encode(address(oak)));
    }

    function test_B_BurnerDeploysBeforeSubscriptionExists() public {
        OakBurner deployed = deployer.deploy(address(oak), oracle, safe);
        assertEq(address(deployed.oak()), address(oak));
    }

    function test_DeployAcceptsMatchingTokensAndDecimals() public {
        OakBurner deployed = deployer.deploy(address(oak), oracle, safe);
        assertEq(address(deployed.oak()), address(oak));
        assertEq(address(deployed.oracle()), oracle);
        assertEq(deployed.oakDecimals(), 18);
    }

    function test_DeployRejectsWrongOakDecimals() public {
        vm.mockCall(address(oak), abi.encodeWithSignature("decimals()"), abi.encode(uint8(6)));
        vm.expectRevert(abi.encodeWithSignature("TokenDecimalsMismatch(address,uint8,uint8)", address(oak), 18, 6));
        deployer.deploy(address(oak), oracle, safe);
    }

    function test_DeployRejectsWrongUsdgDecimals() public {
        vm.mockCall(USDG, abi.encodeWithSignature("decimals()"), abi.encode(uint8(18)));
        vm.expectRevert(abi.encodeWithSignature("TokenDecimalsMismatch(address,uint8,uint8)", USDG, 6, 18));
        deployer.deploy(address(oak), oracle, safe);
    }

    function test_DeployRejectsOracleTokenMismatch() public {
        vm.mockCall(oracle, abi.encodeWithSignature("oakToken()"), abi.encode(address(123)));
        vm.expectRevert(abi.encodeWithSignature("TokenMismatch(address,address)", oracle, address(123)));
        deployer.deploy(address(oak), oracle, safe);
    }

    function test_DeployDoesNotDependOnSubscriptionToken() public {
        vm.mockCall(subscription, abi.encodeWithSignature("oak()"), abi.encode(address(123)));
        deployer.deploy(address(oak), oracle, safe);
    }

    function test_DeployRejectsUnreadableOracleToken() public {
        vm.mockCallRevert(oracle, abi.encodeWithSignature("oakToken()"), bytes("unreadable"));
        vm.expectRevert(bytes("unreadable"));
        deployer.deploy(address(oak), oracle, safe);
    }
}
