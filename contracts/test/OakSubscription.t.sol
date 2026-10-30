// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {OakSubscription} from "../src/OakSubscription.sol";
import {IOakOracle} from "../src/interfaces/IOakOracle.sol";
import {IOakSubscription} from "../src/interfaces/IOakSubscription.sol";
import {IOakSubscriptionErrors} from "../src/interfaces/IOakSubscriptionErrors.sol";
import {OakMerkle} from "../src/libraries/OakMerkle.sol";
import {OakPriceNote, PriceNote} from "../src/libraries/OakPriceNote.sol";
import {MockOracle} from "./mocks/MockOracle.sol";

contract MockUSDG is ERC20 {
    mapping(address authorizer => mapping(bytes32 nonce => bool used)) private _authorizationState;
    address public failRecipient;
    bool public shortTransferFrom;
    bool public forceAuthorizationNoop;
    bool public authorizationStateReverts;
    address public reentryTarget;
    bytes public reentryData;
    bool public reentryAttempted;
    bool public reentrySucceeded;
    bytes4 public reentryRevertSelector;

    constructor() ERC20("Global Dollar", "USDG") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setFailRecipient(address recipient) external {
        failRecipient = recipient;
    }

    function setShortTransferFrom(bool enabled) external {
        shortTransferFrom = enabled;
    }

    function setForceAuthorizationNoop(bool enabled) external {
        forceAuthorizationNoop = enabled;
    }

    function setAuthorizationStateReverts(bool enabled) external {
        authorizationStateReverts = enabled;
    }

    function setAuthorizationState(address authorizer, bytes32 nonce, bool state) external {
        _authorizationState[authorizer][nonce] = state;
    }

    function configureReentry(address target, bytes calldata data) external {
        reentryTarget = target;
        reentryData = data;
        reentryAttempted = false;
        reentrySucceeded = false;
        reentryRevertSelector = bytes4(0);
    }

    function authorizationState(address authorizer, bytes32 nonce) external view returns (bool) {
        require(!authorizationStateReverts, "authorizationState read");
        return _authorizationState[authorizer][nonce];
    }

    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256,
        uint256,
        bytes32 nonce,
        uint8,
        bytes32,
        bytes32
    ) external {
        _receiveWithAuthorization(from, to, value, nonce);
    }

    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256,
        uint256,
        bytes32 nonce,
        bytes calldata
    ) external {
        _receiveWithAuthorization(from, to, value, nonce);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        bool transferred;
        if (!shortTransferFrom) {
            transferred = super.transferFrom(from, to, value);
        } else {
            _spendAllowance(from, _msgSender(), value);
            _transfer(from, to, value - 1);
            transferred = true;
        }
        _attemptReentry();
        return transferred;
    }

    function _receiveWithAuthorization(address from, address to, uint256 value, bytes32 nonce) private {
        require(msg.sender == to, "caller must be payee");
        if (_authorizationState[from][nonce] || forceAuthorizationNoop) return;
        _authorizationState[from][nonce] = true;
        _transfer(from, to, value);
    }

    function _attemptReentry() private {
        address target = reentryTarget;
        if (target == address(0)) return;

        bytes memory data = reentryData;
        reentryTarget = address(0);
        reentryAttempted = true;
        (bool success, bytes memory result) = target.call(data);
        reentrySucceeded = success;
        if (!success && result.length >= 4) {
            bytes4 selector;
            assembly ("memory-safe") {
                selector := mload(add(result, 0x20))
            }
            reentryRevertSelector = selector;
        }
    }

    function _update(address from, address to, uint256 value) internal override {
        if (to != address(0) && to == failRecipient) revert("payout failed");
        super._update(from, to, value);
    }
}

contract ToggleRevertingOracle is IOakOracle {
    bool public revertEverything;
    address private _priceSigner;

    function setRevertEverything(bool enabled) external {
        revertEverything = enabled;
    }

    function syncPhase() external view returns (uint8) {
        _requireReadable();
        return 1;
    }

    function phase() external view returns (uint8) {
        _requireReadable();
        return 1;
    }

    function available() external view returns (bool) {
        _requireReadable();
        return true;
    }

    function ethUsdE18() external view returns (uint256) {
        _requireReadable();
        return 2_000e18;
    }

    function spotOakPerEthE18() external view returns (uint256) {
        _requireReadable();
        return 2_000_000e18;
    }

    function verifyNote(PriceNote calldata n, bytes calldata, address) external view returns (uint256) {
        _requireReadable();
        return n.oakPerEthE18;
    }

    function liquidityUsdgE6() external view returns (uint256) {
        _requireReadable();
        return 1;
    }

    function supplyNet() external view returns (uint256) {
        _requireReadable();
        return 1_000_000e18;
    }

    function priceSigner() external view returns (address) {
        _requireReadable();
        return _priceSigner;
    }

    function setPriceSigner(address signer) external {
        _requireReadable();
        _priceSigner = signer;
        emit PriceSignerSet(signer);
    }

    function _requireReadable() private view {
        require(!revertEverything, "oracle read");
    }
}

contract EmptyLineageNode {
    address public immutable previous;

    constructor(address previous_) {
        previous = previous_;
    }

    function hasRecord(address) external pure returns (bool) {
        return false;
    }
}

contract MockOak is ERC20 {
    constructor() ERC20("Oak", "OAK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }
}

contract CurveSubscriptionHandler {
    MockUSDG private immutable _usdg;
    OakSubscription private immutable _subscription;

    constructor(MockUSDG usdg_, OakSubscription subscription_) {
        _usdg = usdg_;
        _subscription = subscription_;
        usdg_.approve(address(subscription_), type(uint256).max);
    }

    function subscribe(uint256 maxPrice) external {
        if (_subscription.plan(address(this)) != _subscription.PLAN_NONE()) return;
        PriceNote memory empty;
        try _subscription.subscribe(_subscription.PLAN_NO_HOLD(), 0, maxPrice, empty, "") {} catch {}
    }

    function renew(uint256 maxPrice) external {
        if (_subscription.plan(address(this)) != _subscription.PLAN_NO_HOLD()) return;
        PriceNote memory empty;
        try _subscription.renewNoHold(maxPrice, empty, "") {} catch {}
    }

    function cancel() external {
        _subscription.cancel();
    }
}

contract OakSubscriptionTest is StdInvariant, Test {
    uint8 private constant HOLDER = 1;
    uint8 private constant NO_HOLD = 2;
    uint256 private constant SIGNER_KEY = 0xA11CE;
    uint256 private constant NEW_SIGNER_KEY = 0xB0B;
    uint256 private constant NOW = 1_800_000_000;
    uint256 private constant DEFAULT_OAK_PER_ETH = 2_000_000e18;
    uint256 private constant DEFAULT_ETH_USD = 2_000e18;
    uint256 private constant DEFAULT_SUPPLY = 1_000_000e18;
    uint256 private constant DEFAULT_COUNT = 20_000e18;
    uint256 private constant DEFAULT_BURN = 1_000e18;
    uint256 private constant DEFAULT_TRACKED_COUNT = DEFAULT_COUNT - DEFAULT_BURN;

    address private constant SAFE = address(0x5000);
    address private constant BURNER = address(0xB0B0);
    address private constant TREASURY = address(0xC0C0);
    address private constant ETH_USD_SOURCE = address(0xE700);
    address private constant SPOT_SOURCE = address(0x5907);

    address private user;
    address private user2;
    address private user3;
    address private attacker;
    MockUSDG private usdg;
    MockOak private oak;
    MockOracle private oracle;
    OakSubscription private subscription;
    OakSubscription private curveInvariantSubscription;
    CurveSubscriptionHandler private curveHandler;

    function setUp() public {
        vm.chainId(4663);
        vm.warp(NOW);
        user = makeAddr("user");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        attacker = makeAddr("attacker");

        usdg = new MockUSDG();
        oak = new MockOak();
        oracle = new MockOracle(ETH_USD_SOURCE, SPOT_SOURCE);
        oracle.setPhase(1);
        oracle.setEthUsdE18(DEFAULT_ETH_USD);
        oracle.setSpotOakPerEthE18(DEFAULT_OAK_PER_ETH);
        oracle.setSupplyNet(DEFAULT_SUPPLY);
        oracle.setPriceSigner(vm.addr(SIGNER_KEY));
        subscription = _deploy(address(0), oracle);

        _fundAndApprove(user, subscription, 100_000e18);
        _fundAndApprove(user2, subscription, 100_000e18);
        _fundAndApprove(user3, subscription, 0);

        MockOracle curveOracle = new MockOracle(address(0xE701), address(0x5908));
        curveOracle.setPhase(0);
        curveInvariantSubscription = _deploy(address(0), curveOracle);
        curveHandler = new CurveSubscriptionHandler(usdg, curveInvariantSubscription);
        usdg.mint(address(curveHandler), 1_000_000_000_000);
        targetContract(address(curveHandler));
    }

    function test_SubscribeHolderSplits25_75Exactly() public {
        _subscribeHolder(subscription, user, bytes32(uint256(1)));
        assertEq(usdg.balanceOf(BURNER), 2_250_000);
        assertEq(usdg.balanceOf(TREASURY), 6_750_000);
        assertEq(usdg.balanceOf(address(subscription)), 0);
    }

    function test_SubscribeQuotesCeilEntryCountButStoresPostBurnCountAndEmitsBoth() public {
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(2)));
        vm.prank(user);
        (uint256 count, uint256 burnAmount) = subscription.quoteHolder(note, sig);
        assertEq(count, DEFAULT_COUNT);
        assertEq(burnAmount, DEFAULT_BURN);

        vm.expectEmit(true, false, false, true, address(subscription));
        emit IOakSubscription.Subscribed(
            user, HOLDER, uint64(NOW + 30 days), DEFAULT_TRACKED_COUNT, DEFAULT_BURN, false
        );
        vm.prank(user);
        subscription.subscribe(HOLDER, count, 0, note, sig);

        assertEq(subscription.signupOakCount(user), DEFAULT_TRACKED_COUNT);
    }

    function test_SubscribeRevertsWhenCountExceedsMaxCount_AcceptsEqual() public {
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(3)));
        vm.prank(user);
        (uint256 count,) = subscription.quoteHolder(note, sig);
        vm.prank(user);
        vm.expectRevert();
        subscription.subscribe(HOLDER, count - 1, 0, note, sig);
        assertFalse(subscription.noteUsed(note.wallet, note.nonce));
        vm.prank(user);
        subscription.subscribe(HOLDER, count, 0, note, sig);
    }

    function test_SignupBurnsCeil5PctSameTx_ViaBurnFrom_TotalSupplyFalls() public {
        uint256 supplyBefore = oak.totalSupply();
        (, uint256 burnAmount) = _subscribeHolder(subscription, user, bytes32(uint256(4)));
        assertEq(burnAmount, DEFAULT_BURN);
        assertEq(supplyBefore - oak.totalSupply(), burnAmount);
    }

    function test_SignupExactBurnAllowanceSuffices_NeverUnlimited() public {
        vm.prank(user);
        oak.approve(address(subscription), DEFAULT_BURN);
        _subscribeHolder(subscription, user, bytes32(uint256(5)));
        assertEq(oak.allowance(user, address(subscription)), 0);
        assertNotEq(oak.allowance(user, address(subscription)), type(uint256).max);
    }

    function test_RejoinAfterCancelBurnsAgain() public {
        uint256 supplyBefore = oak.totalSupply();
        _subscribeHolder(subscription, user, bytes32(uint256(6)));
        vm.prank(user);
        subscription.cancel();
        _subscribeHolder(subscription, user, bytes32(uint256(7)));
        assertEq(supplyBefore - oak.totalSupply(), 2 * DEFAULT_BURN);
    }

    function test_RenewMakesNoOracleCall_TakesNoNote_RevertingOracleStillRenews() public {
        _subscribeHolder(subscription, user, bytes32(uint256(8)));
        uint64 beforePaid = subscription.paidUntil(user);
        oracle.setSourceUnreadable(ETH_USD_SOURCE, true);
        vm.prank(user);
        subscription.renew();
        assertEq(subscription.paidUntil(user), beforePaid + 30 days);

        (PriceNote memory note, bytes memory sig) = _note(subscription, user2, bytes32(uint256(9)));
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, ETH_USD_SOURCE));
        subscription.subscribe(HOLDER, type(uint256).max, 0, note, sig);
    }

    function test_HolderRenewRevertsBeforeAllowancePaymentWhenBalanceBelowTrackedCount() public {
        _subscribeHolder(subscription, user, bytes32(uint256(8001)));
        uint256 required = subscription.signupOakCount(user);
        uint256 walletBalance = oak.balanceOf(user);
        vm.prank(user);
        assertTrue(oak.transfer(attacker, walletBalance - required + 1));

        uint64 paidBefore = subscription.paidUntil(user);
        uint256 usdgBefore = usdg.balanceOf(user);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OakSubscription.InsufficientOak.selector, required - 1, required));
        subscription.renew();

        assertEq(subscription.paidUntil(user), paidBefore);
        assertEq(usdg.balanceOf(user), usdgBefore);
        assertEq(usdg.balanceOf(address(subscription)), 0);
    }

    function test_HolderRenewWithAuthorizationRevertsBeforePaymentWhenBalanceBelowTrackedCount() public {
        _subscribeHolder(subscription, user, bytes32(uint256(8002)));
        uint256 required = subscription.signupOakCount(user);
        uint256 walletBalance = oak.balanceOf(user);
        vm.prank(user);
        assertTrue(oak.transfer(attacker, walletBalance - required + 1));

        uint64 paidBefore = subscription.paidUntil(user);
        bytes32 authNonce = bytes32(uint256(8003));
        bytes memory auth = _authorization(user, address(subscription), subscription.PRICE(), authNonce);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OakSubscription.InsufficientOak.selector, required - 1, required));
        subscription.renewWithAuthorization(auth);

        assertEq(subscription.paidUntil(user), paidBefore);
        assertFalse(usdg.authorizationState(user, authNonce));
        assertEq(usdg.balanceOf(address(subscription)), 0);
    }

    function testFuzz_HolderRenewSucceedsAtOrAboveTrackedCount(uint96 rawExcess) public {
        _subscribeHolder(subscription, user, bytes32(uint256(8004)));
        uint256 required = subscription.signupOakCount(user);
        uint256 excess = bound(uint256(rawExcess), 0, oak.balanceOf(user) - required);
        uint256 transferAmount = oak.balanceOf(user) - required - excess;
        if (transferAmount != 0) {
            vm.prank(user);
            assertTrue(oak.transfer(attacker, transferAmount));
        }

        uint64 paidBefore = subscription.paidUntil(user);
        vm.prank(user);
        subscription.renew();

        assertEq(oak.balanceOf(user), required + excess);
        assertEq(subscription.paidUntil(user), paidBefore + 30 days);
        assertTrue(subscription.hasAccess(user));
    }

    function test_NoHoldNeverBurnsOrRequiresHolding() public {
        (PriceNote memory note, bytes memory sig) = _note(subscription, user3, bytes32(uint256(10)));
        uint256 supplyBefore = oak.totalSupply();
        vm.prank(user3);
        subscription.subscribe(NO_HOLD, 0, 12_333_333, note, sig);
        assertEq(oak.balanceOf(user3), 0);
        assertEq(oak.totalSupply(), supplyBefore);
        assertEq(subscription.signupOakCount(user3), 0);
    }

    function test_NoHoldRenewStillRequiresNoOak() public {
        _subscribeNoHold(subscription, user3, bytes32(uint256(8005)), type(uint256).max);
        uint64 paidBefore = subscription.paidUntil(user3);
        (PriceNote memory note, bytes memory sig) = _note(subscription, user3, bytes32(uint256(8006)));
        vm.prank(user3);
        subscription.renewNoHold(type(uint256).max, note, sig);

        assertEq(oak.balanceOf(user3), 0);
        assertEq(subscription.paidUntil(user3), paidBefore + 30 days);
        assertTrue(subscription.hasAccess(user3));
    }

    function test_CurveState_NoHoldFloor12_333_333_NoNoteNeeded_HolderClosedPlainRevert() public {
        oracle.setPhase(0);
        PriceNote memory empty;
        vm.prank(user3);
        assertEq(subscription.quoteNoHold(empty, hex"deadbeef"), 12_333_333);
        vm.prank(user3);
        subscription.subscribe(NO_HOLD, 0, 12_333_333, empty, hex"deadbeef");
        vm.prank(user2);
        vm.expectRevert(bytes4(keccak256("HolderClosed()")));
        subscription.quoteHolder(empty, "");
    }

    function test_CurveState_TwoWalletsNoHoldEmptyNotes_SecondSucceeds() public {
        oracle.setPhase(0);
        PriceNote memory empty;
        vm.prank(user2);
        subscription.subscribe(NO_HOLD, 0, 12_333_333, empty, "");
        vm.prank(user3);
        subscription.subscribe(NO_HOLD, 0, 12_333_333, empty, "");
        assertEq(subscription.plan(user2), subscription.PLAN_NO_HOLD());
        assertEq(subscription.plan(user3), subscription.PLAN_NO_HOLD());
        assertFalse(subscription.noteUsed(address(0), bytes32(0)));
    }

    function test_ReadyState_HolderOpens_NoHoldRepricesFromNoteAndEthUsdAverage() public {
        assertTrue(subscription.holderOpen());
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(11)));
        vm.prank(user);
        assertEq(subscription.quoteNoHold(note, sig), 12_333_333);
        vm.prank(user);
        (uint256 count, uint256 burnAmount) = subscription.quoteHolder(note, sig);
        assertEq(count, DEFAULT_COUNT);
        assertEq(burnAmount, DEFAULT_BURN);
    }

    function test_ReadyState_EthUsdgPoolUnreadable_HolderSignupNoHoldSignupNoHoldRenewalAllRevertOracleUnreadable_NeverFloor()
        public
    {
        _subscribeNoHold(subscription, user, bytes32(uint256(12)), type(uint256).max);
        oracle.setSourceUnreadable(ETH_USD_SOURCE, true);

        _expectOracleUnreadableOnFresh(user2, HOLDER, bytes32(uint256(13)));
        _expectOracleUnreadableOnFresh(user3, NO_HOLD, bytes32(uint256(14)));

        (PriceNote memory renewNote, bytes memory renewSig) = _note(subscription, user, bytes32(uint256(15)));
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, ETH_USD_SOURCE));
        subscription.renewNoHold(type(uint256).max, renewNote, renewSig);
    }

    function test_ReadyState_SpotUnreadable_NoteRejected_SameFailClosed() public {
        oracle.setSourceUnreadable(SPOT_SOURCE, true);
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(16)));
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, SPOT_SOURCE));
        subscription.subscribe(HOLDER, type(uint256).max, 0, note, sig);
        assertFalse(subscription.noteUsed(note.wallet, note.nonce));
    }

    function test_ReadyState_OutageDoesNotBlockHolderRenewal() public {
        _subscribeHolder(subscription, user, bytes32(uint256(17)));
        oracle.setSourceUnreadable(ETH_USD_SOURCE, true);
        oracle.setSourceUnreadable(SPOT_SOURCE, true);
        vm.prank(user);
        subscription.renew();
        assertEq(subscription.paidUntil(user), uint64(NOW + 60 days));
    }

    function test_NoteSingleUseNonce_SecondUseRevertsNoteUsed() public {
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(18)));
        vm.prank(user);
        subscription.subscribe(HOLDER, DEFAULT_COUNT, 0, note, sig);
        vm.prank(user);
        subscription.cancel();

        vm.prank(user);
        vm.expectRevert(bytes4(keccak256("NoteUsed()")));
        subscription.subscribe(HOLDER, DEFAULT_COUNT, 0, note, sig);
    }

    function test_NoteNonceNotConsumedWhenSettlementReverts_SameNoteRetrySucceeds() public {
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(19)));
        vm.prank(user);
        vm.expectRevert();
        subscription.subscribe(HOLDER, DEFAULT_COUNT - 1, 0, note, sig);
        assertFalse(subscription.noteUsed(note.wallet, note.nonce));

        vm.prank(user);
        subscription.subscribe(HOLDER, DEFAULT_COUNT, 0, note, sig);
        assertTrue(subscription.noteUsed(note.wallet, note.nonce));
    }

    function test_NoteExpiredAndFutureRejected_BoundariesExact() public {
        _expectQuoteFailure(user, bytes32(uint256(20)), uint64(NOW + 1), IOakOracle.NoteNotYetValid.selector);
        _expectQuoteSuccess(user, bytes32(uint256(21)), uint64(NOW));
        _expectQuoteSuccess(user, bytes32(uint256(22)), uint64(NOW - 300));
        _expectQuoteFailure(user, bytes32(uint256(23)), uint64(NOW - 301), IOakOracle.NoteExpired.selector);
    }

    function test_NoteBoundToOtherWalletRejected() public {
        (PriceNote memory note, bytes memory sig) = _note(subscription, user2, bytes32(uint256(24)));
        vm.prank(user);
        vm.expectRevert(IOakOracle.NoteWrongWallet.selector);
        subscription.quoteHolder(note, sig);
    }

    function test_NoteBoundToBurnerOrOtherContractRejected() public {
        (PriceNote memory burnerNote, bytes memory burnerSig) =
            _signedNote(subscription, address(0), bytes32(uint256(25)), DEFAULT_OAK_PER_ETH, uint64(NOW), SIGNER_KEY);
        vm.prank(user);
        vm.expectRevert(IOakOracle.NoteWrongWallet.selector);
        subscription.quoteHolder(burnerNote, burnerSig);

        OakSubscription other = _deploy(address(0), oracle);
        (PriceNote memory wrongDomain, bytes memory wrongDomainSig) =
            _signedNote(other, user, bytes32(uint256(26)), DEFAULT_OAK_PER_ETH, uint64(NOW), SIGNER_KEY);
        vm.prank(user);
        vm.expectRevert(IOakOracle.NoteBadSignature.selector);
        subscription.quoteHolder(wrongDomain, wrongDomainSig);
    }

    function test_NoteOutsideGuardRejected_EndpointsAccepted() public {
        _quoteAtOakPerEth(DEFAULT_OAK_PER_ETH / 2, bytes32(uint256(27)), true);
        _quoteAtOakPerEth(DEFAULT_OAK_PER_ETH * 3 / 2, bytes32(uint256(28)), true);
        _quoteAtOakPerEth(DEFAULT_OAK_PER_ETH / 2 - 1, bytes32(uint256(29)), false);
        _quoteAtOakPerEth(DEFAULT_OAK_PER_ETH * 3 / 2 + 1, bytes32(uint256(30)), false);
    }

    function test_SignerSwappedOnOracle_OldNoteRejectedFreshAccepted() public {
        (PriceNote memory oldNote, bytes memory oldSig) = _note(subscription, user, bytes32(uint256(31)));
        oracle.setPriceSigner(vm.addr(NEW_SIGNER_KEY));
        vm.prank(user);
        vm.expectRevert(IOakOracle.NoteBadSignature.selector);
        subscription.quoteHolder(oldNote, oldSig);

        (PriceNote memory fresh, bytes memory freshSig) =
            _signedNote(subscription, user, bytes32(uint256(32)), DEFAULT_OAK_PER_ETH, uint64(NOW), NEW_SIGNER_KEY);
        vm.prank(user);
        (uint256 count,) = subscription.quoteHolder(fresh, freshSig);
        assertEq(count, DEFAULT_COUNT);
    }

    function test_ZeroSignerRejectsEveryNote_FloorStillQuotedInCurve() public {
        oracle.setPriceSigner(address(0));
        PriceNote memory empty;
        oracle.setPhase(0);
        vm.prank(user);
        assertEq(subscription.quoteNoHold(empty, ""), 12_333_333);

        oracle.setPhase(1);
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(33)));
        vm.prank(user);
        vm.expectRevert(IOakOracle.NoteBadSignature.selector);
        subscription.quoteHolder(note, sig);
    }

    function test_NoHoldRevertsAbovemaxPrice_AcceptsEqual() public {
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(34)));
        vm.prank(user);
        uint256 price = subscription.quoteNoHold(note, sig);
        vm.prank(user);
        vm.expectRevert();
        subscription.subscribe(NO_HOLD, 0, price - 1, note, sig);
        assertFalse(subscription.noteUsed(note.wallet, note.nonce));
        vm.prank(user);
        subscription.subscribe(NO_HOLD, 0, price, note, sig);
        assertEq(subscription.plan(user), NO_HOLD);
    }

    function test_RejectedNoteRevertsSignupStoresNothing() public {
        (PriceNote memory note, bytes memory sig) = _note(subscription, user2, bytes32(uint256(35)));
        vm.prank(user);
        vm.expectRevert(IOakOracle.NoteWrongWallet.selector);
        subscription.subscribe(HOLDER, type(uint256).max, 0, note, sig);
        assertEq(subscription.plan(user), 0);
        assertFalse(subscription.hasRecord(user));
        assertFalse(subscription.noteUsed(note.wallet, note.nonce));
        assertEq(usdg.balanceOf(BURNER), 0);
    }

    function test_AmountMustEqualComputedPrice() public {
        uint256 price = subscription.PRICE();
        usdg.mint(address(subscription), price);
        usdg.setShortTransferFrom(true);
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(36)));
        uint256 userBalance = usdg.balanceOf(user);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OakSubscription.PaymentAmountMismatch.selector, price, price - 1));
        subscription.subscribe(HOLDER, DEFAULT_COUNT, 0, note, sig);
        assertEq(usdg.balanceOf(user), userBalance);
        assertEq(usdg.balanceOf(address(subscription)), price);
        assertFalse(subscription.hasRecord(user));
        assertFalse(subscription.noteUsed(note.wallet, note.nonce));
    }

    function test_PaidUntilExtendsFromMaxNowPaidUntil() public {
        _subscribeHolder(subscription, user, bytes32(uint256(37)));
        uint64 first = subscription.paidUntil(user);
        vm.warp(NOW + 1 days);
        vm.prank(user);
        subscription.renew();
        assertEq(subscription.paidUntil(user), first + 30 days);
    }

    function test_PrepayCappedAt90Days() public {
        _subscribeHolder(subscription, user, bytes32(uint256(38)));
        vm.prank(user);
        subscription.renew();
        assertEq(subscription.paidUntil(user), uint64(NOW + 60 days));
        vm.warp(NOW - 1);
        vm.prank(user);
        vm.expectRevert();
        subscription.renew();
        vm.warp(NOW);
        vm.prank(user);
        subscription.renew();
        assertEq(subscription.paidUntil(user), uint64(NOW + 90 days));
    }

    function test_SubscribeRevertsWhenPlanActive() public {
        _subscribeHolder(subscription, user, bytes32(uint256(39)));
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(40)));
        vm.prank(user);
        vm.expectRevert();
        subscription.subscribe(HOLDER, type(uint256).max, 0, note, sig);
    }

    function test_CancelClearsPlanCountForfeitsDays() public {
        _subscribeHolder(subscription, user, bytes32(uint256(41)));
        vm.prank(user);
        subscription.cancel();
        assertEq(subscription.plan(user), 0);
        assertEq(subscription.signupOakCount(user), 0);
        assertEq(subscription.paidUntil(user), 0);
        assertFalse(subscription.hasAccess(user));
    }

    function test_CancelWorksWhileLapsed() public {
        _subscribeHolder(subscription, user, bytes32(uint256(42)));
        vm.warp(NOW + 31 days);
        vm.prank(user);
        subscription.cancel();
        assertEq(subscription.plan(user), 0);
    }

    function test_CancelWorksAfterRetire() public {
        _subscribeHolder(subscription, user, bytes32(uint256(43)));
        vm.prank(SAFE);
        subscription.retire();
        vm.prank(user);
        subscription.cancel();
        assertEq(subscription.plan(user), 0);
    }

    function test_HasRecordFalseBeforeSignup_TrueAfter_StaysTrueAfterCancel() public {
        assertFalse(subscription.hasRecord(user));
        _subscribeHolder(subscription, user, bytes32(uint256(44)));
        assertTrue(subscription.hasRecord(user));
        vm.prank(user);
        subscription.cancel();
        assertTrue(subscription.hasRecord(user));
    }

    function test_ExpiresAtEqualsPaidUntil() public {
        _subscribeHolder(subscription, user, bytes32(uint256(45)));
        assertEq(subscription.expiresAt(user), subscription.paidUntil(user));
    }

    function test_SweepToTreasuryMovesOnlyStrayUSDG() public {
        usdg.mint(address(subscription), 77);
        uint256 beforeTreasury = usdg.balanceOf(TREASURY);
        vm.prank(attacker);
        subscription.sweepToTreasury();
        assertEq(usdg.balanceOf(TREASURY), beforeTreasury + 77);
        assertEq(usdg.balanceOf(address(subscription)), 0);
    }

    function test_RetireOnlySafe_OneWay_BlocksSubscribeAndRenew_ReadsWork() public {
        _subscribeHolder(subscription, user, bytes32(uint256(46)));
        vm.prank(attacker);
        vm.expectRevert();
        subscription.retire();
        vm.prank(SAFE);
        subscription.retire();
        assertTrue(subscription.retired());
        assertEq(subscription.plan(user), HOLDER);

        vm.prank(SAFE);
        vm.expectRevert(IOakSubscriptionErrors.Retired.selector);
        subscription.retire();
        vm.prank(user);
        vm.expectRevert(IOakSubscriptionErrors.Retired.selector);
        subscription.renew();

        (PriceNote memory note, bytes memory sig) = _note(subscription, user2, bytes32(uint256(47)));
        vm.prank(user2);
        vm.expectRevert(IOakSubscriptionErrors.Retired.selector);
        subscription.subscribe(HOLDER, type(uint256).max, 0, note, sig);
    }

    function test_ExactEntryHoldingJoinsTracksPostBurnHasAccessAndRenews_OneBelowRefused() public {
        address exact = makeAddr("exact");
        address short = makeAddr("short");
        _fundAndApprove(exact, subscription, DEFAULT_COUNT);
        _fundAndApprove(short, subscription, DEFAULT_COUNT - 1);
        _subscribeHolder(subscription, exact, bytes32(uint256(48)));
        assertEq(oak.balanceOf(exact), DEFAULT_TRACKED_COUNT);
        assertEq(subscription.signupOakCount(exact), DEFAULT_TRACKED_COUNT);
        assertTrue(subscription.hasAccess(exact));

        uint256 supplyAfterSignup = oak.totalSupply();
        uint64 paidAfterSignup = subscription.paidUntil(exact);
        vm.prank(exact);
        subscription.renew();
        assertEq(oak.totalSupply(), supplyAfterSignup);
        assertEq(oak.balanceOf(exact), DEFAULT_TRACKED_COUNT);
        assertEq(subscription.signupOakCount(exact), DEFAULT_TRACKED_COUNT);
        assertEq(subscription.paidUntil(exact), paidAfterSignup + 30 days);
        assertTrue(subscription.hasAccess(exact));

        (PriceNote memory note, bytes memory sig) = _note(subscription, short, bytes32(uint256(49)));
        vm.prank(short);
        vm.expectRevert(
            abi.encodeWithSelector(OakSubscription.InsufficientOak.selector, DEFAULT_COUNT - 1, DEFAULT_COUNT)
        );
        subscription.subscribe(HOLDER, DEFAULT_COUNT, 0, note, sig);
        assertFalse(subscription.hasRecord(short));
        assertEq(usdg.balanceOf(address(subscription)), 0);
    }

    function test_OnlySafeSetsPayees_RejectsZeroAndSelf() public {
        vm.prank(attacker);
        vm.expectRevert();
        subscription.setPayees(address(1), address(2));
        vm.startPrank(SAFE);
        vm.expectRevert();
        subscription.setPayees(address(0), address(2));
        vm.expectRevert();
        subscription.setPayees(address(subscription), address(2));
        subscription.setPayees(address(1), address(2));
        vm.stopPrank();
        assertEq(subscription.burner(), address(1));
        assertEq(subscription.treasury(), address(2));
    }

    function test_PayoutFailureRollsBackAll() public {
        usdg.setFailRecipient(BURNER);
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(50)));
        uint256 oakSupply = oak.totalSupply();
        vm.prank(user);
        vm.expectRevert(bytes("payout failed"));
        subscription.subscribe(HOLDER, DEFAULT_COUNT, 0, note, sig);
        assertFalse(subscription.hasRecord(user));
        assertFalse(subscription.noteUsed(note.wallet, note.nonce));
        assertEq(oak.totalSupply(), oakSupply);
        assertEq(usdg.balanceOf(address(subscription)), 0);
        assertEq(usdg.balanceOf(BURNER), 0);
    }

    function test_ContractHoldsNoBalanceAfterSettle() public {
        _subscribeHolder(subscription, user, bytes32(uint256(51)));
        vm.prank(user);
        subscription.renew();
        assertEq(usdg.balanceOf(address(subscription)), 0);
    }

    function test_AbiHasNoSignerSetterOrImportFunctions() public {
        (bool signerSetter,) = address(subscription).call(abi.encodeWithSignature("setPriceSigner(address)", user));
        (bool importRecord,) =
            address(subscription).call(abi.encodeWithSignature("importRecord(address,uint256)", user, 1));
        (bool setOracle,) = address(subscription).call(abi.encodeWithSignature("setOracle(address)", user));
        assertFalse(signerSetter);
        assertFalse(importRecord);
        assertFalse(setOracle);
    }

    function test_SubscribeWithAuthorizationChecksUnusedAndExactDelta() public {
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(52)));
        bytes32 authNonce = bytes32(uint256(1001));
        bytes memory auth = _authorization(user, address(subscription), subscription.PRICE(), authNonce);
        uint256 burnerBefore = usdg.balanceOf(BURNER);
        uint256 treasuryBefore = usdg.balanceOf(TREASURY);
        vm.prank(user);
        subscription.subscribeWithAuthorization(DEFAULT_COUNT, note, sig, auth);
        assertTrue(usdg.authorizationState(user, authNonce));
        assertEq(subscription.plan(user), HOLDER);
        assertEq(usdg.balanceOf(address(subscription)), 0);
        _assertSplitDelta(subscription.PRICE(), burnerBefore, treasuryBefore);
    }

    function test_SubscribeWithAuthorizationAcceptsBytesSignatureOverload() public {
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(520)));
        bytes32 authNonce = bytes32(uint256(10010));
        bytes memory auth = abi.encodeWithSignature(
            "receiveWithAuthorization(address,address,uint256,uint256,uint256,bytes32,bytes)",
            user,
            address(subscription),
            subscription.PRICE(),
            0,
            type(uint256).max,
            authNonce,
            hex"1234"
        );
        vm.prank(user);
        subscription.subscribeWithAuthorization(DEFAULT_COUNT, note, sig, auth);
        assertTrue(usdg.authorizationState(user, authNonce));
    }

    function test_ReplayedAndCancelledAuthorizationNoOpFixturesRevertBeforeSettlement() public {
        (PriceNote memory firstNote, bytes memory firstSig) = _note(subscription, user, bytes32(uint256(53)));
        bytes32 usedNonce = bytes32(uint256(1002));
        bytes memory usedAuth = _authorization(user, address(subscription), subscription.PRICE(), usedNonce);
        vm.prank(user);
        subscription.subscribeWithAuthorization(DEFAULT_COUNT, firstNote, firstSig, usedAuth);
        vm.prank(user);
        subscription.cancel();
        usdg.mint(address(subscription), subscription.PRICE());

        (PriceNote memory replayNote, bytes memory replaySig) = _note(subscription, user, bytes32(uint256(54)));
        vm.prank(user);
        vm.expectRevert(OakSubscription.AuthorizationAlreadyUsed.selector);
        subscription.subscribeWithAuthorization(DEFAULT_COUNT, replayNote, replaySig, usedAuth);
        assertFalse(subscription.noteUsed(replayNote.wallet, replayNote.nonce));
        assertEq(subscription.plan(user), 0);

        bytes32 cancelledNonce = bytes32(uint256(1003));
        usdg.setAuthorizationState(user2, cancelledNonce, true);
        bytes memory cancelledAuth = _authorization(user2, address(subscription), subscription.PRICE(), cancelledNonce);
        (PriceNote memory cancelledNote, bytes memory cancelledSig) = _note(subscription, user2, bytes32(uint256(55)));
        vm.prank(user2);
        vm.expectRevert(OakSubscription.AuthorizationAlreadyUsed.selector);
        subscription.subscribeWithAuthorization(DEFAULT_COUNT, cancelledNote, cancelledSig, cancelledAuth);
        assertFalse(subscription.hasRecord(user2));
    }

    function test_AuthorizationSuccessfulNoOpRevertsAllSubscriptionStateAndPayouts() public {
        uint256 price = subscription.PRICE();
        usdg.mint(address(subscription), price);
        usdg.setForceAuthorizationNoop(true);
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(56)));
        bytes memory auth = _authorization(user, address(subscription), price, bytes32(uint256(1004)));
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OakSubscription.PaymentAmountMismatch.selector, price, 0));
        subscription.subscribeWithAuthorization(DEFAULT_COUNT, note, sig, auth);
        assertFalse(subscription.hasRecord(user));
        assertFalse(subscription.noteUsed(note.wallet, note.nonce));
        assertEq(usdg.balanceOf(address(subscription)), price);
        assertEq(usdg.balanceOf(BURNER), 0);
        assertEq(usdg.balanceOf(TREASURY), 0);
    }

    function test_AuthorizationCallerBindingPrecedesTokenReads_AllWrappers() public {
        usdg.setAuthorizationStateReverts(true);
        bytes memory auth = _authorization(user, address(subscription), subscription.PRICE(), bytes32(uint256(1005)));
        PriceNote memory empty;
        bytes32[] memory proof = new bytes32[](0);
        vm.startPrank(attacker);
        vm.expectRevert(bytes("authorization from must equal caller"));
        subscription.subscribeWithAuthorization(type(uint256).max, empty, "", auth);
        vm.expectRevert(bytes("authorization from must equal caller"));
        subscription.subscribeGrandfatheredWithAuthorization(DEFAULT_COUNT, proof, auth);
        vm.expectRevert(bytes("authorization from must equal caller"));
        subscription.renewWithAuthorization(auth);
        vm.stopPrank();
    }

    function test_RenewWithAuthorizationUsedAndNoOpCannotAdvancePaidUntil() public {
        _subscribeHolder(subscription, user, bytes32(uint256(57)));
        uint64 beforePaid = subscription.paidUntil(user);
        uint256 price = subscription.PRICE();
        usdg.mint(address(subscription), price);
        bytes32 usedNonce = bytes32(uint256(1006));
        usdg.setAuthorizationState(user, usedNonce, true);
        bytes memory usedAuth = _authorization(user, address(subscription), price, usedNonce);
        vm.prank(user);
        vm.expectRevert(OakSubscription.AuthorizationAlreadyUsed.selector);
        subscription.renewWithAuthorization(usedAuth);
        assertEq(subscription.paidUntil(user), beforePaid);

        usdg.setForceAuthorizationNoop(true);
        bytes memory noopAuth = _authorization(user, address(subscription), price, bytes32(uint256(1007)));
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OakSubscription.PaymentAmountMismatch.selector, price, 0));
        subscription.renewWithAuthorization(noopAuth);
        assertEq(subscription.paidUntil(user), beforePaid);
    }

    function test_GrandfatherCarriesPaidTime_NoBurn_AndAuthorizationNoOpRollsBack() public {
        (uint256 count,) = _subscribeHolder(subscription, user, bytes32(uint256(58)));
        uint64 sourcePaid = subscription.paidUntil(user);
        uint256 supplyAfterSource = oak.totalSupply();
        OakSubscription successor = _deploy(address(subscription), oracle);
        _approveFor(user, successor);
        bytes32 root = OakMerkle.grandfatherLeaf(user, count, address(subscription));
        vm.prank(SAFE);
        successor.setGrandfatherRoot(root, uint64(NOW + 120 days));

        bytes32[] memory proof = new bytes32[](0);
        uint256 price = successor.PRICE();
        usdg.mint(address(successor), price);
        usdg.setForceAuthorizationNoop(true);
        bytes memory auth = _authorization(user, address(successor), price, bytes32(uint256(1008)));
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OakSubscription.PaymentAmountMismatch.selector, price, 0));
        successor.subscribeGrandfatheredWithAuthorization(count, proof, auth);
        assertFalse(successor.hasRecord(user));

        usdg.setForceAuthorizationNoop(false);
        uint256 burnerBefore = usdg.balanceOf(BURNER);
        uint256 treasuryBefore = usdg.balanceOf(TREASURY);
        vm.prank(user);
        successor.subscribeGrandfathered(count, proof);
        assertEq(successor.paidUntil(user), sourcePaid + 30 days);
        assertEq(successor.signupOakCount(user), count);
        assertTrue(successor.grandfathered(user));
        assertEq(oak.totalSupply(), supplyAfterSource);
        _assertSplitDelta(successor.PRICE(), burnerBefore, treasuryBefore);
    }

    function test_GrandfatherWalksPastEmptyMiddleToNewestRecordedAncestor() public {
        (uint256 count,) = _subscribeHolder(subscription, user, bytes32(uint256(59)));
        OakSubscription emptyMiddle = _deploy(address(subscription), oracle);
        OakSubscription newest = _deploy(address(emptyMiddle), oracle);
        _approveFor(user, newest);
        bytes32 root = OakMerkle.grandfatherLeaf(user, count, address(subscription));
        vm.prank(SAFE);
        newest.setGrandfatherRoot(root, uint64(NOW + 120 days));
        vm.prank(user);
        newest.subscribeGrandfathered(count, new bytes32[](0));
        assertTrue(newest.hasRecord(user));
    }

    function test_GrandfatherCancelledAuthoritativeSourceBlocksOlderPaidRecord() public {
        _subscribeHolder(subscription, user, bytes32(uint256(60)));
        OakSubscription middle = _deploy(address(subscription), oracle);
        _approveFor(user, middle);
        (uint256 middleCount,) = _subscribeHolder(middle, user, bytes32(uint256(61)));
        vm.prank(user);
        middle.cancel();

        OakSubscription newest = _deploy(address(middle), oracle);
        _approveFor(user, newest);
        bytes32 oldRoot = OakMerkle.grandfatherLeaf(user, DEFAULT_COUNT, address(subscription));
        vm.prank(SAFE);
        newest.setGrandfatherRoot(oldRoot, uint64(NOW + 120 days));
        vm.prank(user);
        vm.expectRevert();
        newest.subscribeGrandfathered(middleCount, new bytes32[](0));
        assertFalse(newest.hasRecord(user));
    }

    function test_SetGrandfatherRootOnlySafeOnceRequiresPredecessorAndWindow() public {
        vm.prank(SAFE);
        vm.expectRevert();
        subscription.setGrandfatherRoot(bytes32(uint256(1)), uint64(NOW + 1 days));

        OakSubscription successor = _deploy(address(subscription), oracle);
        vm.prank(attacker);
        vm.expectRevert();
        successor.setGrandfatherRoot(bytes32(uint256(1)), uint64(NOW + 1 days));
        vm.prank(SAFE);
        vm.expectRevert();
        successor.setGrandfatherRoot(bytes32(uint256(1)), uint64(NOW + 120 days + 1));
        vm.prank(SAFE);
        successor.setGrandfatherRoot(bytes32(uint256(1)), uint64(NOW + 120 days));
        vm.prank(SAFE);
        vm.expectRevert();
        successor.setGrandfatherRoot(bytes32(uint256(2)), uint64(NOW + 120 days));
    }

    function test_FreshSuccessorRecordSurvivesCancelAndBlocksGrandfatherRecovery() public {
        (uint256 sourceCount,) = _subscribeHolder(subscription, user, bytes32(uint256(62)));
        OakSubscription successor = _deploy(address(subscription), oracle);
        _approveFor(user, successor);
        _subscribeHolder(successor, user, bytes32(uint256(63)));
        vm.prank(user);
        successor.cancel();
        bytes32 root = OakMerkle.grandfatherLeaf(user, sourceCount, address(subscription));
        vm.prank(SAFE);
        successor.setGrandfatherRoot(root, uint64(NOW + 120 days));
        vm.prank(user);
        vm.expectRevert();
        successor.subscribeGrandfathered(sourceCount, new bytes32[](0));
    }

    function test_RetireBlocksAllSevenPaymentEntrypoints() public {
        (uint256 holderCount,) = _subscribeHolder(subscription, user, bytes32(uint256(7001)));
        _subscribeNoHold(subscription, user2, bytes32(uint256(7002)), type(uint256).max);

        OakSubscription successor = _deploy(address(subscription), oracle);
        _approveFor(user, successor);
        _setGrandfatherRoot(successor, user, holderCount, address(subscription), uint64(NOW + 120 days));

        vm.startPrank(SAFE);
        successor.retire();
        subscription.retire();
        vm.stopPrank();

        oak.mint(user3, DEFAULT_COUNT + DEFAULT_BURN);
        (PriceNote memory freshNote, bytes memory freshSig) = _note(subscription, user3, bytes32(uint256(7003)));
        bytes memory freshAuth =
            _authorization(user3, address(subscription), subscription.PRICE(), bytes32(uint256(7101)));
        vm.startPrank(user3);
        vm.expectRevert(IOakSubscriptionErrors.Retired.selector);
        subscription.subscribe(HOLDER, DEFAULT_COUNT, 0, freshNote, freshSig);
        vm.expectRevert(IOakSubscriptionErrors.Retired.selector);
        subscription.subscribeWithAuthorization(DEFAULT_COUNT, freshNote, freshSig, freshAuth);
        vm.stopPrank();

        bytes32[] memory proof = new bytes32[](0);
        bytes memory grandfatherAuth =
            _authorization(user, address(successor), successor.PRICE(), bytes32(uint256(7102)));
        vm.startPrank(user);
        vm.expectRevert(IOakSubscriptionErrors.Retired.selector);
        successor.subscribeGrandfathered(holderCount, proof);
        vm.expectRevert(IOakSubscriptionErrors.Retired.selector);
        successor.subscribeGrandfatheredWithAuthorization(holderCount, proof, grandfatherAuth);
        vm.stopPrank();

        bytes memory renewAuth =
            _authorization(user, address(subscription), subscription.PRICE(), bytes32(uint256(7103)));
        vm.startPrank(user);
        vm.expectRevert(IOakSubscriptionErrors.Retired.selector);
        subscription.renew();
        vm.expectRevert(IOakSubscriptionErrors.Retired.selector);
        subscription.renewWithAuthorization(renewAuth);
        vm.stopPrank();

        (PriceNote memory renewNote, bytes memory renewSig) = _note(subscription, user2, bytes32(uint256(7004)));
        vm.prank(user2);
        vm.expectRevert(IOakSubscriptionErrors.Retired.selector);
        subscription.renewNoHold(type(uint256).max, renewNote, renewSig);
    }

    function test_SubscribeWithAuthorizationPinsMaxCountAndNoteUse() public {
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(7201)));
        vm.prank(user);
        (uint256 count,) = subscription.quoteHolder(note, sig);

        bytes32 authNonce = bytes32(uint256(7202));
        bytes memory auth = _authorization(user, address(subscription), subscription.PRICE(), authNonce);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OakSubscription.CountAboveMaximum.selector, count, count - 1));
        subscription.subscribeWithAuthorization(count - 1, note, sig, auth);
        assertFalse(usdg.authorizationState(user, authNonce));
        assertFalse(subscription.noteUsed(note.wallet, note.nonce));

        vm.prank(user);
        subscription.subscribeWithAuthorization(count, note, sig, auth);
        assertTrue(usdg.authorizationState(user, authNonce));
        assertTrue(subscription.noteUsed(note.wallet, note.nonce));

        vm.prank(user);
        subscription.cancel();
        bytes32 secondAuthNonce = bytes32(uint256(7203));
        bytes memory secondAuth = _authorization(user, address(subscription), subscription.PRICE(), secondAuthNonce);
        vm.prank(user);
        vm.expectRevert(bytes4(keccak256("NoteUsed()")));
        subscription.subscribeWithAuthorization(count, note, sig, secondAuth);
        assertFalse(usdg.authorizationState(user, secondAuthNonce));
    }

    function test_SubscribeWithAuthorizationRequiresEntryCountAndTracksPostBurn() public {
        OakSubscription target = _deploy(address(0), oracle);
        oak.mint(user3, DEFAULT_COUNT - 1);
        _approveFor(user3, target);
        (PriceNote memory note, bytes memory sig) = _note(target, user3, bytes32(uint256(7210)));
        bytes32 authNonce = bytes32(uint256(7211));
        bytes memory auth = _authorization(user3, address(target), target.PRICE(), authNonce);

        vm.prank(user3);
        vm.expectRevert(
            abi.encodeWithSelector(OakSubscription.InsufficientOak.selector, DEFAULT_COUNT - 1, DEFAULT_COUNT)
        );
        target.subscribeWithAuthorization(DEFAULT_COUNT, note, sig, auth);
        assertFalse(target.noteUsed(note.wallet, note.nonce));
        assertFalse(target.hasRecord(user3));
        assertFalse(usdg.authorizationState(user3, authNonce));

        oak.mint(user3, 1);
        uint256 supplyBefore = oak.totalSupply();
        vm.prank(user3);
        target.subscribeWithAuthorization(DEFAULT_COUNT, note, sig, auth);
        assertEq(supplyBefore - oak.totalSupply(), DEFAULT_BURN);
        assertEq(oak.balanceOf(user3), DEFAULT_TRACKED_COUNT);
        assertEq(target.signupOakCount(user3), DEFAULT_TRACKED_COUNT);
        assertTrue(target.hasAccess(user3));
        assertTrue(target.noteUsed(note.wallet, note.nonce));
        assertTrue(usdg.authorizationState(user3, authNonce));
    }

    function test_InvalidAuthorizationRejectsShortSelectorPayeeAndValueExactly() public {
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(7220)));

        vm.prank(user);
        vm.expectRevert(OakSubscription.InvalidAuthorization.selector);
        subscription.subscribeWithAuthorization(DEFAULT_COUNT, note, sig, new bytes(195));

        bytes memory badSelector = abi.encodeWithSelector(
            bytes4(0xdeadbeef),
            user,
            address(subscription),
            subscription.PRICE(),
            0,
            type(uint256).max,
            bytes32(uint256(7221)),
            uint8(27),
            bytes32(uint256(1)),
            bytes32(uint256(2))
        );
        vm.prank(user);
        vm.expectRevert(OakSubscription.InvalidAuthorization.selector);
        subscription.subscribeWithAuthorization(DEFAULT_COUNT, note, sig, badSelector);

        bytes memory wrongPayee = _authorization(user, attacker, subscription.PRICE(), bytes32(uint256(7222)));
        vm.prank(user);
        vm.expectRevert(OakSubscription.InvalidAuthorization.selector);
        subscription.subscribeWithAuthorization(DEFAULT_COUNT, note, sig, wrongPayee);

        bytes memory wrongValue =
            _authorization(user, address(subscription), subscription.PRICE() - 1, bytes32(uint256(7223)));
        vm.prank(user);
        vm.expectRevert(OakSubscription.InvalidAuthorization.selector);
        subscription.subscribeWithAuthorization(DEFAULT_COUNT, note, sig, wrongValue);

        assertFalse(subscription.noteUsed(note.wallet, note.nonce));
        assertFalse(subscription.hasRecord(user));
    }

    function test_ReentrantTokenCallbackIsRejectedAndOuterSettlementSucceeds() public {
        usdg.configureReentry(address(subscription), abi.encodeCall(OakSubscription.sweepToTreasury, ()));
        _subscribeHolder(subscription, user, bytes32(uint256(7230)));

        assertTrue(usdg.reentryAttempted());
        assertFalse(usdg.reentrySucceeded());
        assertEq(usdg.reentryRevertSelector(), ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        assertEq(subscription.paidUntil(user), uint64(NOW + 30 days));
        assertEq(usdg.balanceOf(address(subscription)), 0);
    }

    function test_GrandfatherRejectsNonHolderSourceAndCountMismatchExactly() public {
        OakSubscription noHoldSource = _deploy(address(0), oracle);
        _approveFor(user, noHoldSource);
        _subscribeNoHold(noHoldSource, user, bytes32(uint256(7301)), type(uint256).max);
        OakSubscription noHoldSuccessor = _deploy(address(noHoldSource), oracle);
        _approveFor(user, noHoldSuccessor);
        _setGrandfatherRoot(noHoldSuccessor, user, 0, address(noHoldSource), uint64(NOW + 120 days));
        vm.prank(user);
        vm.expectRevert(OakSubscription.GrandfatherSourceInvalid.selector);
        noHoldSuccessor.subscribeGrandfathered(0, new bytes32[](0));

        (uint256 count,) = _subscribeHolder(subscription, user2, bytes32(uint256(7302)));
        OakSubscription wrongCountSuccessor = _deploy(address(subscription), oracle);
        _approveFor(user2, wrongCountSuccessor);
        _setGrandfatherRoot(wrongCountSuccessor, user2, count + 1, address(subscription), uint64(NOW + 120 days));
        assertGe(oak.balanceOf(user2), count + 1);
        vm.prank(user2);
        vm.expectRevert(OakSubscription.GrandfatherSourceInvalid.selector);
        wrongCountSuccessor.subscribeGrandfathered(count + 1, new bytes32[](0));
    }

    function test_GrandfatherRejectsBadProofAndInsufficientOakExactly() public {
        (uint256 count,) = _subscribeHolder(subscription, user, bytes32(uint256(7310)));
        OakSubscription badProofSuccessor = _deploy(address(subscription), oracle);
        _approveFor(user, badProofSuccessor);
        _setGrandfatherRoot(badProofSuccessor, user, count, address(subscription), uint64(NOW + 120 days));
        bytes32[] memory badProof = new bytes32[](1);
        badProof[0] = bytes32(uint256(0xBAD));
        vm.prank(user);
        vm.expectRevert(OakSubscription.InvalidGrandfatherProof.selector);
        badProofSuccessor.subscribeGrandfathered(count, badProof);

        (uint256 lowCount,) = _subscribeHolder(subscription, user2, bytes32(uint256(7311)));
        uint256 lowBalance = lowCount - 1;
        uint256 amountToTransfer = oak.balanceOf(user2) - lowBalance;
        vm.prank(user2);
        assertTrue(oak.transfer(attacker, amountToTransfer));
        OakSubscription lowBalanceSuccessor = _deploy(address(subscription), oracle);
        _approveFor(user2, lowBalanceSuccessor);
        _setGrandfatherRoot(lowBalanceSuccessor, user2, lowCount, address(subscription), uint64(NOW + 120 days));
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(OakSubscription.InsufficientOak.selector, lowBalance, lowCount));
        lowBalanceSuccessor.subscribeGrandfathered(lowCount, new bytes32[](0));
    }

    function test_GrandfatherDeadlineBoundaryAndDoubleUse() public {
        (uint256 count,) = _subscribeHolder(subscription, user, bytes32(uint256(7320)));
        OakSubscription atDeadline = _deploy(address(subscription), oracle);
        OakSubscription afterDeadline = _deploy(address(subscription), oracle);
        _approveFor(user, atDeadline);
        _approveFor(user, afterDeadline);
        uint64 deadline = uint64(NOW + 1);
        _setGrandfatherRoot(atDeadline, user, count, address(subscription), deadline);
        _setGrandfatherRoot(afterDeadline, user, count, address(subscription), deadline);

        vm.warp(deadline);
        uint256 burnerBefore = usdg.balanceOf(BURNER);
        uint256 treasuryBefore = usdg.balanceOf(TREASURY);
        vm.prank(user);
        atDeadline.subscribeGrandfathered(count, new bytes32[](0));
        assertTrue(atDeadline.grandfathered(user));
        _assertSplitDelta(atDeadline.PRICE(), burnerBefore, treasuryBefore);

        vm.prank(user);
        vm.expectRevert(OakSubscription.GrandfatherUnavailable.selector);
        atDeadline.subscribeGrandfathered(count, new bytes32[](0));

        vm.warp(uint256(deadline) + 1);
        vm.prank(user);
        vm.expectRevert(OakSubscription.GrandfatherUnavailable.selector);
        afterDeadline.subscribeGrandfathered(count, new bytes32[](0));
    }

    function test_GrandfatherLineageDepth255SucceedsDepth256Reverts() public {
        (uint256 count,) = _subscribeHolder(subscription, user, bytes32(uint256(7330)));
        address lineageHead = address(subscription);
        for (uint256 i; i < 255; ++i) {
            lineageHead = address(new EmptyLineageNode(lineageHead));
        }

        OakSubscription depth255 = _deploy(lineageHead, oracle);
        _approveFor(user, depth255);
        _setGrandfatherRoot(depth255, user, count, address(subscription), uint64(NOW + 120 days));
        vm.prank(user);
        depth255.subscribeGrandfathered(count, new bytes32[](0));
        assertTrue(depth255.grandfathered(user));

        address depth256Head = address(new EmptyLineageNode(lineageHead));
        OakSubscription depth256 = _deploy(depth256Head, oracle);
        _approveFor(user, depth256);
        _setGrandfatherRoot(depth256, user, count, address(subscription), uint64(NOW + 120 days));
        vm.prank(user);
        vm.expectRevert(OakSubscription.LineageTooDeep.selector);
        depth256.subscribeGrandfathered(count, new bytes32[](0));
    }

    function test_GrandfatherWithAuthorizationSucceedsAndSplitsExactly() public {
        (uint256 count,) = _subscribeHolder(subscription, user, bytes32(uint256(7340)));
        OakSubscription successor = _deploy(address(subscription), oracle);
        _approveFor(user, successor);
        _setGrandfatherRoot(successor, user, count, address(subscription), uint64(NOW + 120 days));
        bytes32 authNonce = bytes32(uint256(7341));
        bytes memory auth = _authorization(user, address(successor), successor.PRICE(), authNonce);
        uint256 oakSupplyBefore = oak.totalSupply();
        uint256 burnerBefore = usdg.balanceOf(BURNER);
        uint256 treasuryBefore = usdg.balanceOf(TREASURY);

        vm.prank(user);
        successor.subscribeGrandfatheredWithAuthorization(count, new bytes32[](0), auth);

        assertTrue(usdg.authorizationState(user, authNonce));
        assertTrue(successor.hasRecord(user));
        assertTrue(successor.grandfathered(user));
        assertEq(successor.plan(user), HOLDER);
        assertEq(successor.signupOakCount(user), count);
        assertEq(oak.totalSupply(), oakSupplyBefore);
        assertEq(usdg.balanceOf(address(successor)), 0);
        _assertSplitDelta(successor.PRICE(), burnerBefore, treasuryBefore);
    }

    function test_SignupBurnCeilsWhenCountIsNotDivisibleByTwenty() public {
        (PriceNote memory note, bytes memory sig) =
            _signedNote(subscription, user, bytes32(uint256(7401)), DEFAULT_OAK_PER_ETH + 1, uint64(NOW), SIGNER_KEY);
        vm.prank(user);
        (uint256 count, uint256 burnAmount) = subscription.quoteHolder(note, sig);
        assertEq(count, 20_000_000_000_000_020_000_001);
        assertEq(count % 20, 1);
        assertEq(burnAmount, count / 20 + 1);

        uint256 supplyBefore = oak.totalSupply();
        vm.prank(user);
        subscription.subscribe(HOLDER, count, 0, note, sig);
        assertEq(supplyBefore - oak.totalSupply(), burnAmount);
        assertEq(subscription.signupOakCount(user), count - burnAmount);
    }

    function test_RenewNeverTouchesRevertEverythingOracle() public {
        ToggleRevertingOracle revertingOracle = new ToggleRevertingOracle();
        OakSubscription target = _deploy(address(0), revertingOracle);
        _approveFor(user, target);
        _subscribeHolder(target, user, bytes32(uint256(7410)));
        uint64 paidBefore = target.paidUntil(user);

        revertingOracle.setRevertEverything(true);
        vm.expectRevert(bytes("oracle read"));
        revertingOracle.phase();

        vm.prank(user);
        target.renew();
        assertEq(target.paidUntil(user), paidBefore + 30 days);
    }

    function test_RenewNoHoldPinsMaxPriceAndOddSplit() public {
        uint256 firstPrice = _subscribeNoHold(subscription, user, bytes32(uint256(7420)), type(uint256).max);
        assertEq(firstPrice, 12_333_333);
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(7421)));
        vm.prank(user);
        uint256 price = subscription.quoteNoHold(note, sig);
        uint64 paidBefore = subscription.paidUntil(user);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OakSubscription.PriceAboveMaximum.selector, price, price - 1));
        subscription.renewNoHold(price - 1, note, sig);
        assertEq(subscription.paidUntil(user), paidBefore);
        assertFalse(subscription.noteUsed(note.wallet, note.nonce));

        uint256 burnerBefore = usdg.balanceOf(BURNER);
        uint256 treasuryBefore = usdg.balanceOf(TREASURY);
        vm.prank(user);
        subscription.renewNoHold(price, note, sig);
        assertTrue(subscription.noteUsed(note.wallet, note.nonce));
        assertEq(subscription.paidUntil(user), paidBefore + 30 days);
        _assertSplitDelta(price, burnerBefore, treasuryBefore);
    }

    function test_ReadyPricingAbove100kUsesCurveAndExactSplit() public {
        oracle.setSupplyNet(200_000_000e18);
        (PriceNote memory note, bytes memory sig) = _note(subscription, user, bytes32(uint256(7430)));
        vm.prank(user);
        uint256 price = subscription.quoteNoHold(note, sig);
        assertEq(price, 14_625_000);
        assertGt(price, 12_333_333);

        uint256 burnerBefore = usdg.balanceOf(BURNER);
        uint256 treasuryBefore = usdg.balanceOf(TREASURY);
        vm.prank(user);
        subscription.subscribe(NO_HOLD, 0, price, note, sig);
        assertTrue(subscription.noteUsed(note.wallet, note.nonce));
        _assertSplitDelta(price, burnerBefore, treasuryBefore);
    }

    function test_NoHoldSubscribeOddAmountSplitsExactly() public {
        oracle.setPhase(0);
        PriceNote memory empty;
        uint256 burnerBefore = usdg.balanceOf(BURNER);
        uint256 treasuryBefore = usdg.balanceOf(TREASURY);
        vm.prank(user3);
        subscription.subscribe(NO_HOLD, 0, 12_333_333, empty, "");
        _assertSplitDelta(12_333_333, burnerBefore, treasuryBefore);
    }

    function test_HolderRenewalAllowanceAndAuthorizationSplitExactly() public {
        _subscribeHolder(subscription, user, bytes32(uint256(7440)));
        uint256 burnerBefore = usdg.balanceOf(BURNER);
        uint256 treasuryBefore = usdg.balanceOf(TREASURY);
        vm.prank(user);
        subscription.renew();
        _assertSplitDelta(subscription.PRICE(), burnerBefore, treasuryBefore);

        OakSubscription authTarget = _deploy(address(0), oracle);
        _approveFor(user2, authTarget);
        _subscribeHolder(authTarget, user2, bytes32(uint256(7441)));
        bytes32 authNonce = bytes32(uint256(7442));
        bytes memory auth = _authorization(user2, address(authTarget), authTarget.PRICE(), authNonce);
        burnerBefore = usdg.balanceOf(BURNER);
        treasuryBefore = usdg.balanceOf(TREASURY);
        vm.prank(user2);
        authTarget.renewWithAuthorization(auth);
        assertTrue(usdg.authorizationState(user2, authNonce));
        _assertSplitDelta(authTarget.PRICE(), burnerBefore, treasuryBefore);
    }

    function test_HasAccessPinsHolderBalanceAndExpiryBoundaries() public {
        (uint256 count,) = _subscribeHolder(subscription, user, bytes32(uint256(7450)));
        assertTrue(subscription.hasAccess(user));
        uint256 amountToTransfer = oak.balanceOf(user) - count;
        vm.prank(user);
        assertTrue(oak.transfer(attacker, amountToTransfer));
        assertEq(oak.balanceOf(user), count);
        assertTrue(subscription.hasAccess(user));
        vm.prank(user);
        assertTrue(oak.transfer(attacker, 1));
        assertEq(oak.balanceOf(user), count - 1);
        assertFalse(subscription.hasAccess(user));

        _subscribeNoHold(subscription, user2, bytes32(uint256(7451)), type(uint256).max);
        uint64 expiry = subscription.paidUntil(user2);
        vm.warp(expiry);
        assertTrue(subscription.hasAccess(user2));
        vm.warp(uint256(expiry) + 1);
        assertFalse(subscription.hasAccess(user2));
    }

    function testFuzz_CurveNoHoldNeverConsumesEmptyNonce(uint96 extra) public {
        uint256 maxPrice = 12_333_333 + uint256(extra);
        address wallet = makeAddr("fuzz-wallet");
        usdg.mint(wallet, maxPrice);
        vm.prank(wallet);
        usdg.approve(address(curveInvariantSubscription), maxPrice);
        PriceNote memory empty;
        vm.prank(wallet);
        curveInvariantSubscription.subscribe(NO_HOLD, 0, maxPrice, empty, "");
        assertFalse(curveInvariantSubscription.noteUsed(address(0), bytes32(0)));
        assertEq(curveInvariantSubscription.signupOakCount(wallet), 0);
    }

    function invariant_CurveSettlementNeverHoldsUSDGOrConsumesEmptyNonce() public view {
        assertEq(usdg.balanceOf(address(curveInvariantSubscription)), 0);
        assertFalse(curveInvariantSubscription.noteUsed(address(0), bytes32(0)));
        assertEq(curveInvariantSubscription.signupOakCount(address(curveHandler)), 0);
    }

    function _deploy(address previous_, IOakOracle oracle_) private returns (OakSubscription) {
        return new OakSubscription(address(usdg), address(oak), address(oracle_), BURNER, TREASURY, SAFE, previous_);
    }

    function _setGrandfatherRoot(OakSubscription target, address wallet, uint256 count, address source, uint64 deadline)
        private
    {
        bytes32 root = OakMerkle.grandfatherLeaf(wallet, count, source);
        vm.prank(SAFE);
        target.setGrandfatherRoot(root, deadline);
    }

    function _assertSplitDelta(uint256 amount, uint256 burnerBefore, uint256 treasuryBefore) private view {
        uint256 expectedBurner = amount / 4;
        assertEq(usdg.balanceOf(BURNER) - burnerBefore, expectedBurner);
        assertEq(usdg.balanceOf(TREASURY) - treasuryBefore, amount - expectedBurner);
    }

    function _fundAndApprove(address wallet, OakSubscription target, uint256 oakAmount) private {
        usdg.mint(wallet, 1_000_000_000_000);
        if (oakAmount != 0) oak.mint(wallet, oakAmount);
        _approveFor(wallet, target);
    }

    function _approveFor(address wallet, OakSubscription target) private {
        vm.startPrank(wallet);
        usdg.approve(address(target), type(uint256).max);
        oak.approve(address(target), type(uint256).max);
        vm.stopPrank();
    }

    function _subscribeHolder(OakSubscription target, address wallet, bytes32 nonce)
        private
        returns (uint256 count, uint256 burnAmount)
    {
        (PriceNote memory note, bytes memory sig) = _note(target, wallet, nonce);
        uint256 entryCount;
        vm.prank(wallet);
        (entryCount, burnAmount) = target.quoteHolder(note, sig);
        vm.prank(wallet);
        target.subscribe(HOLDER, entryCount, 0, note, sig);
        count = target.signupOakCount(wallet);
    }

    function _subscribeNoHold(OakSubscription target, address wallet, bytes32 nonce, uint256 maxPrice)
        private
        returns (uint256 price)
    {
        (PriceNote memory note, bytes memory sig) = _note(target, wallet, nonce);
        vm.prank(wallet);
        price = target.quoteNoHold(note, sig);
        vm.prank(wallet);
        target.subscribe(NO_HOLD, 0, maxPrice, note, sig);
    }

    function _note(OakSubscription target, address wallet, bytes32 nonce)
        private
        view
        returns (PriceNote memory, bytes memory)
    {
        return _signedNote(target, wallet, nonce, DEFAULT_OAK_PER_ETH, uint64(block.timestamp), SIGNER_KEY);
    }

    function _signedNote(
        OakSubscription target,
        address wallet,
        bytes32 nonce,
        uint256 oakPerEth,
        uint64 timestamp,
        uint256 key
    ) private view returns (PriceNote memory note, bytes memory signature) {
        note = PriceNote({wallet: wallet, oakPerEthE18: oakPerEth, timestamp: timestamp, nonce: nonce});
        bytes32 digest = OakPriceNote.digest(note, address(target));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function _authorization(address from, address to, uint256 value, bytes32 nonce)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "receiveWithAuthorization(address,address,uint256,uint256,uint256,bytes32,uint8,bytes32,bytes32)",
            from,
            to,
            value,
            0,
            type(uint256).max,
            nonce,
            27,
            bytes32(uint256(1)),
            bytes32(uint256(2))
        );
    }

    function _expectOracleUnreadableOnFresh(address wallet, uint8 plan_, bytes32 nonce) private {
        (PriceNote memory note, bytes memory sig) = _note(subscription, wallet, nonce);
        vm.prank(wallet);
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, ETH_USD_SOURCE));
        subscription.subscribe(
            plan_, plan_ == HOLDER ? type(uint256).max : 0, plan_ == HOLDER ? 0 : type(uint256).max, note, sig
        );
    }

    function _expectQuoteFailure(address wallet, bytes32 nonce, uint64 timestamp, bytes4 selector) private {
        (PriceNote memory note, bytes memory sig) =
            _signedNote(subscription, wallet, nonce, DEFAULT_OAK_PER_ETH, timestamp, SIGNER_KEY);
        vm.prank(wallet);
        vm.expectRevert(selector);
        subscription.quoteHolder(note, sig);
    }

    function _expectQuoteSuccess(address wallet, bytes32 nonce, uint64 timestamp) private {
        (PriceNote memory note, bytes memory sig) =
            _signedNote(subscription, wallet, nonce, DEFAULT_OAK_PER_ETH, timestamp, SIGNER_KEY);
        vm.prank(wallet);
        (uint256 count,) = subscription.quoteHolder(note, sig);
        assertEq(count, DEFAULT_COUNT);
    }

    function _quoteAtOakPerEth(uint256 value, bytes32 nonce, bool accepted) private {
        (PriceNote memory note, bytes memory sig) =
            _signedNote(subscription, user, nonce, value, uint64(NOW), SIGNER_KEY);
        vm.prank(user);
        if (accepted) {
            subscription.quoteHolder(note, sig);
        } else {
            vm.expectPartialRevert(IOakOracle.NoteOutsideGuard.selector);
            subscription.quoteHolder(note, sig);
        }
    }
}
