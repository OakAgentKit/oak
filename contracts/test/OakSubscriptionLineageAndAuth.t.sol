// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Test} from "forge-std/Test.sol";

import {OakSubscription} from "../src/OakSubscription.sol";
import {OakMerkle} from "../src/libraries/OakMerkle.sol";
import {OakPriceNote, PriceNote} from "../src/libraries/OakPriceNote.sol";
import {OakPricing} from "../src/libraries/OakPricing.sol";
import {MockOracle} from "./mocks/MockOracle.sol";

contract LineageUSDG is ERC20, EIP712 {
    enum TransferBehavior {
        Exact,
        NoTransfer,
        Short,
        Excess
    }

    bytes32 private constant RECEIVE_TYPEHASH = keccak256(
        "ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
    );
    bytes32 private constant CANCEL_TYPEHASH = keccak256("CancelAuthorization(address authorizer,bytes32 nonce)");

    mapping(address authorizer => mapping(bytes32 nonce => bool used)) private _authorizationState;
    TransferBehavior public authorizationBehavior;
    TransferBehavior public allowanceBehavior;
    address public failRecipient;

    constructor() ERC20("Global Dollar", "USDG") EIP712("Global Dollar", "1") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setAuthorizationBehavior(TransferBehavior behavior) external {
        authorizationBehavior = behavior;
    }

    function setAllowanceBehavior(TransferBehavior behavior) external {
        allowanceBehavior = behavior;
    }

    function setFailRecipient(address recipient) external {
        failRecipient = recipient;
    }

    function authorizationState(address authorizer, bytes32 nonce) external view returns (bool) {
        return _authorizationState[authorizer][nonce];
    }

    function authorizationDigest(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce
    ) external view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(abi.encode(RECEIVE_TYPEHASH, from, to, value, validAfter, validBefore, nonce))
        );
    }

    function cancellationDigest(address authorizer, bytes32 nonce) external view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(CANCEL_TYPEHASH, authorizer, nonce)));
    }

    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(msg.sender == to, "caller must be payee");
        require(block.timestamp > validAfter && block.timestamp < validBefore, "authorization timing");
        require(!_authorizationState[from][nonce], "authorization used");
        bytes32 structHash = keccak256(abi.encode(RECEIVE_TYPEHASH, from, to, value, validAfter, validBefore, nonce));
        require(ECDSA.recover(_hashTypedDataV4(structHash), v, r, s) == from, "authorization signer");
        _authorizationState[from][nonce] = true;
        _moveByBehavior(from, to, value, authorizationBehavior);
    }

    function cancelAuthorization(address authorizer, bytes32 nonce, uint8 v, bytes32 r, bytes32 s) external {
        require(!_authorizationState[authorizer][nonce], "authorization used");
        bytes32 structHash = keccak256(abi.encode(CANCEL_TYPEHASH, authorizer, nonce));
        require(ECDSA.recover(_hashTypedDataV4(structHash), v, r, s) == authorizer, "cancellation signer");
        _authorizationState[authorizer][nonce] = true;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _spendAllowance(from, _msgSender(), value);
        _moveByBehavior(from, to, value, allowanceBehavior);
        return true;
    }

    function _moveByBehavior(address from, address to, uint256 value, TransferBehavior behavior) private {
        if (behavior == TransferBehavior.NoTransfer) return;
        if (behavior == TransferBehavior.Short) {
            _transfer(from, to, value - 1);
        } else if (behavior == TransferBehavior.Excess) {
            _transfer(from, to, value + 1);
        } else {
            _transfer(from, to, value);
        }
    }

    function _update(address from, address to, uint256 value) internal override {
        if (to != address(0) && to == failRecipient) revert("payout failed");
        super._update(from, to, value);
    }
}

contract LineageOak is ERC20 {
    constructor() ERC20("Oak", "OAK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }
}

contract OakSubscriptionLineageAndAuthTest is Test {
    uint8 private constant HOLDER = 1;
    uint8 private constant AUTH_SUBSCRIBE = 0;
    uint8 private constant AUTH_GRANDFATHER = 1;
    uint8 private constant AUTH_RENEW = 2;
    uint256 private constant SIGNER_KEY = 0xA11CE;
    uint256 private constant USER_KEY = 0xB0B;
    uint256 private constant USER2_KEY = 0xCAFE;
    uint256 private constant USER3_KEY = 0xD00D;
    uint256 private constant NOW = 1_800_000_000;
    uint256 private constant OAK_PER_ETH = 2_000_000e18;
    uint256 private constant ETH_USD = 2_000e18;
    uint256 private constant SUPPLY = 1_000_000e18;
    uint256 private constant COUNT = 20_000e18;
    uint256 private constant PRICE = 9_000_000;

    address private constant SAFE = address(0x5000);
    address private constant BURNER = address(0xB0B0);
    address private constant TREASURY = address(0xC0C0);

    struct AuthCase {
        uint8 wrapper;
        OakSubscription target;
        address wallet;
        uint256 walletKey;
        uint256 count;
        PriceNote note;
        bytes noteSignature;
        bytes32[] proof;
        bytes authorization;
        bytes32 authorizationNonce;
    }

    struct StateSnapshot {
        uint8 plan;
        uint64 paidUntil;
        uint256 count;
        bool hasRecord;
        bool grandfathered;
        bool noteUsed;
        bool authorizationUsed;
        address burner;
        address treasury;
        uint256 targetBalance;
        uint256 walletBalance;
        uint256 burnerBalance;
        uint256 treasuryBalance;
        uint256 oakBalance;
        uint256 oakSupply;
    }

    address private user;
    address private user2;
    address private user3;
    address private attacker;
    LineageUSDG private usdg;
    LineageOak private oak;
    MockOracle private oracle;
    OakSubscription private subscription;

    function setUp() public {
        vm.chainId(4663);
        vm.warp(NOW);
        user = vm.addr(USER_KEY);
        user2 = vm.addr(USER2_KEY);
        user3 = vm.addr(USER3_KEY);
        attacker = makeAddr("attacker");

        usdg = new LineageUSDG();
        oak = new LineageOak();
        oracle = new MockOracle(address(0xE700), address(0x5907));
        oracle.setPhase(1);
        oracle.setEthUsdE18(ETH_USD);
        oracle.setSpotOakPerEthE18(OAK_PER_ETH);
        oracle.setSupplyNet(SUPPLY);
        oracle.setPriceSigner(vm.addr(SIGNER_KEY));
        subscription = _deploy(address(0));

        _fundAndApprove(user, subscription);
        _fundAndApprove(user2, subscription);
        _fundAndApprove(user3, subscription);
    }

    function test_GrandfatherRootOnlySafe_Once_RevertsWithoutPrevious() public {
        vm.prank(SAFE);
        vm.expectRevert(OakSubscription.NoPredecessor.selector);
        subscription.setGrandfatherRoot(bytes32(uint256(1)), uint64(block.timestamp + 1 days));

        OakSubscription successor = _deploy(address(subscription));
        vm.prank(attacker);
        vm.expectRevert(OakSubscription.OnlySafe.selector);
        successor.setGrandfatherRoot(bytes32(uint256(1)), uint64(block.timestamp + 1 days));

        vm.prank(SAFE);
        successor.setGrandfatherRoot(bytes32(uint256(1)), uint64(block.timestamp + 1 days));
        vm.prank(SAFE);
        vm.expectRevert(OakSubscription.GrandfatherRootAlreadySet.selector);
        successor.setGrandfatherRoot(bytes32(uint256(2)), uint64(block.timestamp + 2 days));
    }

    function test_GrandfatheredRenewOriginalCountNoBurn_Pays9_SetsHasRecord() public {
        uint256 count = _subscribeHolder(subscription, user, bytes32(uint256(1)));
        assertEq(count, COUNT - OakPricing.signupBurn(COUNT));
        OakSubscription successor = _deploy(address(subscription));
        _approveFor(user, successor);
        _setRoot(successor, user, count, address(subscription), uint64(block.timestamp + 120 days));

        uint256 supplyBefore = oak.totalSupply();
        uint256 burnerBefore = usdg.balanceOf(BURNER);
        uint256 treasuryBefore = usdg.balanceOf(TREASURY);
        vm.prank(user);
        successor.subscribeGrandfathered(count, new bytes32[](0));

        assertEq(successor.signupOakCount(user), count);
        assertTrue(successor.hasRecord(user));
        assertTrue(successor.grandfathered(user));
        assertEq(oak.totalSupply(), supplyBefore);
        assertEq(usdg.balanceOf(BURNER) - burnerBefore, PRICE / 4);
        assertEq(usdg.balanceOf(TREASURY) - treasuryBefore, PRICE - PRICE / 4);
        assertEq(usdg.balanceOf(address(successor)), 0);
    }

    function test_GrandfatheredCarriesOldPaidTime_NotForCancelledOldRecord() public {
        uint256 count = _subscribeHolder(subscription, user, bytes32(uint256(2)));
        uint64 oldPaidUntil = subscription.paidUntil(user);
        OakSubscription successor = _deploy(address(subscription));
        _approveFor(user, successor);
        _setRoot(successor, user, count, address(subscription), uint64(block.timestamp + 120 days));
        vm.prank(user);
        successor.subscribeGrandfathered(count, new bytes32[](0));
        assertEq(successor.paidUntil(user), oldPaidUntil + 30 days);

        uint256 cancelledCount = _subscribeHolder(subscription, user2, bytes32(uint256(3)));
        vm.prank(user2);
        subscription.cancel();
        OakSubscription cancelledSuccessor = _deploy(address(subscription));
        _approveFor(user2, cancelledSuccessor);
        _setRoot(cancelledSuccessor, user2, cancelledCount, address(subscription), uint64(block.timestamp + 120 days));
        vm.prank(user2);
        vm.expectRevert(OakSubscription.GrandfatherSourceInvalid.selector);
        cancelledSuccessor.subscribeGrandfathered(cancelledCount, new bytes32[](0));
        assertFalse(cancelledSuccessor.hasRecord(user2));
    }

    function test_GrandfatheredRejectsWrongProof_Reuse_AfterDeadline_ActivePlan() public {
        uint256 count = _subscribeHolder(subscription, user, bytes32(uint256(4)));
        OakSubscription successor = _deploy(address(subscription));
        _approveFor(user, successor);
        _setRoot(successor, user, count, address(subscription), uint64(block.timestamp + 120 days));
        bytes32[] memory wrongProof = new bytes32[](1);
        wrongProof[0] = bytes32(uint256(0xBAD));
        vm.prank(user);
        vm.expectRevert(OakSubscription.InvalidGrandfatherProof.selector);
        successor.subscribeGrandfathered(count, wrongProof);

        vm.prank(user);
        successor.subscribeGrandfathered(count, new bytes32[](0));
        vm.prank(user);
        vm.expectRevert(OakSubscription.GrandfatherUnavailable.selector);
        successor.subscribeGrandfathered(count, new bytes32[](0));

        OakSubscription activeSuccessor = _deploy(address(subscription));
        _approveFor(user, activeSuccessor);
        _subscribeHolder(activeSuccessor, user, bytes32(uint256(5)));
        _setRoot(activeSuccessor, user, count, address(subscription), uint64(block.timestamp + 120 days));
        vm.prank(user);
        vm.expectRevert(OakSubscription.GrandfatherUnavailable.selector);
        activeSuccessor.subscribeGrandfathered(count, new bytes32[](0));

        OakSubscription expiredSuccessor = _deploy(address(subscription));
        _approveFor(user, expiredSuccessor);
        _setRoot(expiredSuccessor, user, count, address(subscription), uint64(block.timestamp + 1));
        vm.warp(block.timestamp + 2);
        vm.prank(user);
        vm.expectRevert(OakSubscription.GrandfatherUnavailable.selector);
        expiredSuccessor.subscribeGrandfathered(count, new bytes32[](0));
    }

    function test_GrandfatheredRespectsPrepayCap() public {
        uint256 count = _subscribeHolder(subscription, user, bytes32(uint256(6)));
        vm.startPrank(user);
        subscription.renew();
        subscription.renew();
        vm.stopPrank();
        assertEq(subscription.paidUntil(user), uint64(NOW + 90 days));

        OakSubscription successor = _deploy(address(subscription));
        _approveFor(user, successor);
        _setRoot(successor, user, count, address(subscription), uint64(block.timestamp + 120 days));
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(OakSubscription.PrepayCapExceeded.selector, NOW + 120 days, NOW + 90 days)
        );
        successor.subscribeGrandfathered(count, new bytes32[](0));
        assertFalse(successor.hasRecord(user));
    }

    function test_FreshV2SignupThenCancel_GrandfatherBothWrappersReject_HasRecordStaysTrue() public {
        uint256 oldCount = _subscribeHolder(subscription, user, bytes32(uint256(7)));
        vm.prank(user);
        subscription.renew();
        vm.warp(NOW + 20 days);
        assertEq(subscription.paidUntil(user) - block.timestamp, 40 days);

        OakSubscription successor = _deploy(address(subscription));
        _approveFor(user, successor);
        _subscribeHolder(successor, user, bytes32(uint256(8)));
        vm.prank(user);
        successor.cancel();
        assertTrue(successor.hasRecord(user));
        assertEq(successor.paidUntil(user), 0);
        _setRoot(successor, user, oldCount, address(subscription), uint64(block.timestamp + 120 days));

        vm.prank(user);
        vm.expectRevert(OakSubscription.GrandfatherUnavailable.selector);
        successor.subscribeGrandfathered(oldCount, new bytes32[](0));

        bytes memory authorization = _authorization(USER_KEY, address(successor), bytes32(uint256(9)));
        vm.prank(user);
        vm.expectRevert(OakSubscription.GrandfatherUnavailable.selector);
        successor.subscribeGrandfatheredWithAuthorization(oldCount, new bytes32[](0), authorization);
        assertTrue(successor.hasRecord(user));
        assertEq(successor.paidUntil(user), 0);
        assertFalse(usdg.authorizationState(user, bytes32(uint256(9))));
    }

    function test_UnmigratedV1HolderGrandfathersOnV3_UsesV1LiveTimeAndCount() public {
        uint256 count = _subscribeHolder(subscription, user, bytes32(uint256(10)));
        uint64 v1PaidUntil = subscription.paidUntil(user);
        OakSubscription v2 = _deploy(address(subscription));
        OakSubscription v3 = _deploy(address(v2));
        _approveFor(user, v3);
        _setRoot(v3, user, count, address(subscription), uint64(block.timestamp + 120 days));

        vm.prank(user);
        v3.subscribeGrandfathered(count, new bytes32[](0));
        assertEq(v3.signupOakCount(user), count);
        assertEq(v3.paidUntil(user), v1PaidUntil + 30 days);
        assertTrue(v3.hasRecord(user));
        assertFalse(v2.hasRecord(user));
    }

    function test_CancelledV2Authoritative_PaidV1DoesNotRevive() public {
        uint256 v1Count = _subscribeHolder(subscription, user, bytes32(uint256(11)));
        vm.prank(user);
        subscription.renew();
        OakSubscription v2 = _deploy(address(subscription));
        _approveFor(user, v2);
        _subscribeHolder(v2, user, bytes32(uint256(12)));
        vm.prank(user);
        v2.cancel();

        OakSubscription v3 = _deploy(address(v2));
        _approveFor(user, v3);
        _setRoot(v3, user, v1Count, address(subscription), uint64(block.timestamp + 120 days));
        vm.prank(user);
        vm.expectRevert(OakSubscription.GrandfatherSourceInvalid.selector);
        v3.subscribeGrandfathered(v1Count, new bytes32[](0));
        assertFalse(v3.hasRecord(user));
        assertEq(subscription.paidUntil(user), uint64(NOW + 60 days));
    }

    function test_GrandfatherProofWrongOrForeignAncestorRejected() public {
        uint256 v1Count = _subscribeHolder(subscription, user, bytes32(uint256(13)));
        OakSubscription v2 = _deploy(address(subscription));
        _approveFor(user, v2);
        uint256 v2Count = _subscribeHolder(v2, user, bytes32(uint256(14)));

        OakSubscription validV3 = _deploy(address(v2));
        _approveFor(user, validV3);
        _setRoot(validV3, user, v2Count, address(v2), uint64(block.timestamp + 120 days));
        vm.prank(user);
        validV3.subscribeGrandfathered(v2Count, new bytes32[](0));
        assertTrue(validV3.hasRecord(user));

        OakSubscription foreignV3 = _deploy(address(v2));
        _approveFor(user, foreignV3);
        _setRoot(foreignV3, user, v1Count, address(subscription), uint64(block.timestamp + 120 days));
        vm.prank(user);
        vm.expectRevert(OakSubscription.InvalidGrandfatherProof.selector);
        foreignV3.subscribeGrandfathered(v2Count, new bytes32[](0));

        OakSubscription wrongProofV3 = _deploy(address(v2));
        _approveFor(user, wrongProofV3);
        _setRoot(wrongProofV3, user, v2Count, address(v2), uint64(block.timestamp + 120 days));
        bytes32[] memory wrongProof = new bytes32[](1);
        wrongProof[0] = bytes32(uint256(0xF0E1));
        vm.prank(user);
        vm.expectRevert(OakSubscription.InvalidGrandfatherProof.selector);
        wrongProofV3.subscribeGrandfathered(v2Count, wrongProof);
    }

    function test_FreshSignupOnV2DoesNotCarry_AllowedWhileV1Paid() public {
        _subscribeHolder(subscription, user, bytes32(uint256(15)));
        vm.prank(user);
        subscription.renew();
        OakSubscription v2 = _deploy(address(subscription));
        _approveFor(user, v2);
        uint256 v2Count = _subscribeHolder(v2, user, bytes32(uint256(16)));

        assertEq(subscription.paidUntil(user), uint64(NOW + 60 days));
        assertEq(v2.paidUntil(user), uint64(NOW + 30 days));
        assertEq(v2.signupOakCount(user), v2Count);
        assertTrue(v2.hasRecord(user));
    }

    function test_AuthorizationUsedOrCancelledNonceNoOpCannotSettle() public {
        for (uint8 wrapper; wrapper < 3; ++wrapper) {
            _assertUsedOrCancelledCannotSettle(wrapper, false, bytes32(uint256(100 + wrapper)));
            _assertUsedOrCancelledCannotSettle(wrapper, true, bytes32(uint256(200 + wrapper)));
        }
    }

    function test_AuthorizationFalseNonceButNoTransfer_RevertsExactDelta() public {
        for (uint8 wrapper; wrapper < 3; ++wrapper) {
            _assertAuthorizationBehavior(
                wrapper, LineageUSDG.TransferBehavior.NoTransfer, 0, bytes32(uint256(300 + wrapper))
            );
        }
    }

    function test_AuthorizationShortOrExcessTransferReverts_ExactAmountSucceeds() public {
        for (uint8 wrapper; wrapper < 3; ++wrapper) {
            _assertAuthorizationBehavior(
                wrapper, LineageUSDG.TransferBehavior.Short, PRICE - 1, bytes32(uint256(400 + wrapper))
            );
            _assertAuthorizationBehavior(
                wrapper, LineageUSDG.TransferBehavior.Excess, PRICE + 1, bytes32(uint256(500 + wrapper))
            );
        }
    }

    function test_BothPaymentPathsExactReplayRollback() public {
        (PriceNote memory note, bytes memory noteSignature) = _note(subscription, user, bytes32(uint256(600)));
        StateSnapshot memory allowanceBefore = _snapshot(subscription, user, note.nonce, bytes32(uint256(601)));
        usdg.setFailRecipient(BURNER);
        vm.prank(user);
        vm.expectRevert(bytes("payout failed"));
        subscription.subscribe(HOLDER, COUNT, 0, note, noteSignature);
        _assertUnchanged(subscription, user, note.nonce, bytes32(uint256(601)), allowanceBefore);
        usdg.setFailRecipient(address(0));
        vm.prank(user);
        subscription.subscribe(HOLDER, COUNT, 0, note, noteSignature);
        assertTrue(subscription.noteUsed(note.wallet, note.nonce));

        OakSubscription authorizationTarget = _deploy(address(0));
        _approveFor(user, authorizationTarget);
        (PriceNote memory authNote, bytes memory authNoteSignature) =
            _note(authorizationTarget, user, bytes32(uint256(602)));
        bytes32 authorizationNonce = bytes32(uint256(603));
        bytes memory authorization = _authorization(USER_KEY, address(authorizationTarget), authorizationNonce);
        StateSnapshot memory authorizationBefore =
            _snapshot(authorizationTarget, user, authNote.nonce, authorizationNonce);
        usdg.setFailRecipient(BURNER);
        vm.prank(user);
        vm.expectRevert(bytes("payout failed"));
        authorizationTarget.subscribeWithAuthorization(COUNT, authNote, authNoteSignature, authorization);
        _assertUnchanged(authorizationTarget, user, authNote.nonce, authorizationNonce, authorizationBefore);
        usdg.setFailRecipient(address(0));
        vm.prank(user);
        authorizationTarget.subscribeWithAuthorization(COUNT, authNote, authNoteSignature, authorization);
        assertTrue(usdg.authorizationState(user, authorizationNonce));
        assertTrue(authorizationTarget.noteUsed(authNote.wallet, authNote.nonce));
    }

    function test_AuthorizationFromMustEqualCaller_ThirdPartySubmitRejected() public {
        for (uint8 wrapper; wrapper < 3; ++wrapper) {
            AuthCase memory authCase = _prepareAuthCase(wrapper, bytes32(uint256(700 + wrapper)));
            StateSnapshot memory beforeState =
                _snapshot(authCase.target, authCase.wallet, authCase.note.nonce, authCase.authorizationNonce);
            vm.expectRevert(bytes("authorization from must equal caller"));
            _callAuth(authCase, attacker, authCase.count, authCase.proof);
            _assertUnchanged(
                authCase.target, authCase.wallet, authCase.note.nonce, authCase.authorizationNonce, beforeState
            );
            _callAuth(authCase, authCase.wallet, authCase.count, authCase.proof);
            assertTrue(usdg.authorizationState(authCase.wallet, authCase.authorizationNonce));
        }
    }

    function test_AuthorizationReplayAfterOwnerRevert_ThirdPartyRejected_OwnerCanRetry() public {
        _replayAfterSubscribeRevert();
        _replayAfterGrandfatherRevert();
        _replayAfterRenewRevert();
    }

    function testFuzz_PaidUntilMonotonic(uint32 elapsed) public {
        _subscribeHolder(subscription, user, bytes32(uint256(800)));
        uint64 beforePaid = subscription.paidUntil(user);
        uint256 boundedElapsed = bound(uint256(elapsed), 0, 45 days);
        vm.warp(NOW + boundedElapsed);
        uint64 expected = uint64((beforePaid > block.timestamp ? beforePaid : block.timestamp) + 30 days);
        vm.prank(user);
        subscription.renew();
        assertGe(subscription.paidUntil(user), beforePaid);
        assertEq(subscription.paidUntil(user), expected);
    }

    function testFuzz_SplitSumsToAmount(uint128 amount) public pure {
        (uint256 burnShare, uint256 treasuryShare) = OakPricing.splitBurn(uint256(amount));
        assertEq(burnShare + treasuryShare, uint256(amount));
    }

    function testFuzz_CountFixedWhileSubscribed(uint32 elapsed) public {
        uint256 initialCount = _subscribeHolder(subscription, user, bytes32(uint256(801)));
        vm.warp(NOW + bound(uint256(elapsed), 0, 45 days));
        vm.prank(user);
        subscription.renew();
        assertEq(subscription.signupOakCount(user), initialCount);
    }

    function testFuzz_CountMonotoneInOakPerEth(uint96 firstSeed, uint96 secondSeed) public {
        uint256 lower = OAK_PER_ETH / 2;
        uint256 upper = OAK_PER_ETH * 3 / 2;
        uint256 first = bound(uint256(firstSeed), lower, upper);
        uint256 second = bound(uint256(secondSeed), lower, upper);
        if (first > second) (first, second) = (second, first);

        (PriceNote memory firstNote, bytes memory firstSignature) =
            _noteAt(subscription, user, bytes32(uint256(802)), first);
        (PriceNote memory secondNote, bytes memory secondSignature) =
            _noteAt(subscription, user, bytes32(uint256(803)), second);
        vm.prank(user);
        (uint256 firstCount,) = subscription.quoteHolder(firstNote, firstSignature);
        vm.prank(user);
        (uint256 secondCount,) = subscription.quoteHolder(secondNote, secondSignature);
        assertLe(firstCount, secondCount);
    }

    function _assertUsedOrCancelledCannotSettle(uint8 wrapper, bool cancelled, bytes32 seed) private {
        AuthCase memory authCase = _prepareAuthCase(wrapper, seed);
        if (cancelled) {
            _cancelAuthorization(authCase.walletKey, authCase.authorizationNonce);
        } else {
            vm.prank(address(authCase.target));
            (bool success,) = address(usdg).call(authCase.authorization);
            assertTrue(success);
        }
        StateSnapshot memory beforeState =
            _snapshot(authCase.target, authCase.wallet, authCase.note.nonce, authCase.authorizationNonce);
        vm.expectRevert(OakSubscription.AuthorizationAlreadyUsed.selector);
        _callAuth(authCase, authCase.wallet, authCase.count, authCase.proof);
        _assertUnchanged(
            authCase.target, authCase.wallet, authCase.note.nonce, authCase.authorizationNonce, beforeState
        );
    }

    function _assertAuthorizationBehavior(
        uint8 wrapper,
        LineageUSDG.TransferBehavior behavior,
        uint256 received,
        bytes32 seed
    ) private {
        AuthCase memory authCase = _prepareAuthCase(wrapper, seed);
        usdg.setAuthorizationBehavior(behavior);
        StateSnapshot memory beforeState =
            _snapshot(authCase.target, authCase.wallet, authCase.note.nonce, authCase.authorizationNonce);
        vm.expectRevert(abi.encodeWithSelector(OakSubscription.PaymentAmountMismatch.selector, PRICE, received));
        _callAuth(authCase, authCase.wallet, authCase.count, authCase.proof);
        _assertUnchanged(
            authCase.target, authCase.wallet, authCase.note.nonce, authCase.authorizationNonce, beforeState
        );

        usdg.setAuthorizationBehavior(LineageUSDG.TransferBehavior.Exact);
        _callAuth(authCase, authCase.wallet, authCase.count, authCase.proof);
        assertTrue(usdg.authorizationState(authCase.wallet, authCase.authorizationNonce));
        assertEq(usdg.balanceOf(address(authCase.target)), 0);
    }

    function _replayAfterSubscribeRevert() private {
        AuthCase memory authCase = _prepareAuthCase(AUTH_SUBSCRIBE, bytes32(uint256(900)));
        StateSnapshot memory beforeState =
            _snapshot(authCase.target, authCase.wallet, authCase.note.nonce, authCase.authorizationNonce);
        vm.expectRevert(
            abi.encodeWithSelector(OakSubscription.CountAboveMaximum.selector, authCase.count, authCase.count - 1)
        );
        _callAuth(authCase, authCase.wallet, authCase.count - 1, authCase.proof);
        _assertUnchanged(
            authCase.target, authCase.wallet, authCase.note.nonce, authCase.authorizationNonce, beforeState
        );
        vm.expectRevert(bytes("authorization from must equal caller"));
        _callAuth(authCase, attacker, authCase.count, authCase.proof);
        _callAuth(authCase, authCase.wallet, authCase.count, authCase.proof);

        vm.prank(authCase.wallet);
        authCase.target.cancel();
        (authCase.note, authCase.noteSignature) = _note(authCase.target, authCase.wallet, bytes32(uint256(901)));
        vm.expectRevert(OakSubscription.AuthorizationAlreadyUsed.selector);
        _callAuth(authCase, authCase.wallet, authCase.count, authCase.proof);
    }

    function _replayAfterGrandfatherRevert() private {
        AuthCase memory authCase = _prepareAuthCase(AUTH_GRANDFATHER, bytes32(uint256(910)));
        bytes32[] memory wrongProof = new bytes32[](1);
        wrongProof[0] = bytes32(uint256(0xBAD));
        StateSnapshot memory beforeState =
            _snapshot(authCase.target, authCase.wallet, authCase.note.nonce, authCase.authorizationNonce);
        vm.expectRevert(OakSubscription.InvalidGrandfatherProof.selector);
        _callAuth(authCase, authCase.wallet, authCase.count, wrongProof);
        _assertUnchanged(
            authCase.target, authCase.wallet, authCase.note.nonce, authCase.authorizationNonce, beforeState
        );
        vm.expectRevert(bytes("authorization from must equal caller"));
        _callAuth(authCase, attacker, authCase.count, authCase.proof);
        _callAuth(authCase, authCase.wallet, authCase.count, authCase.proof);

        // Clear only receipt flags so the wrapper reaches the consumed-authorization guard again.
        vm.store(address(authCase.target), keccak256(abi.encode(authCase.wallet, uint256(6))), bytes32(uint256(0)));
        vm.store(address(authCase.target), keccak256(abi.encode(authCase.wallet, uint256(7))), bytes32(uint256(0)));
        vm.expectRevert(OakSubscription.AuthorizationAlreadyUsed.selector);
        _callAuth(authCase, authCase.wallet, authCase.count, authCase.proof);
    }

    function _replayAfterRenewRevert() private {
        AuthCase memory authCase = _prepareAuthCase(AUTH_RENEW, bytes32(uint256(920)));
        vm.startPrank(authCase.wallet);
        authCase.target.renew();
        authCase.target.renew();
        vm.stopPrank();
        StateSnapshot memory beforeState =
            _snapshot(authCase.target, authCase.wallet, authCase.note.nonce, authCase.authorizationNonce);
        vm.expectRevert(
            abi.encodeWithSelector(
                OakSubscription.PrepayCapExceeded.selector,
                uint256(authCase.target.paidUntil(authCase.wallet)) + 30 days,
                block.timestamp + 90 days
            )
        );
        _callAuth(authCase, authCase.wallet, authCase.count, authCase.proof);
        _assertUnchanged(
            authCase.target, authCase.wallet, authCase.note.nonce, authCase.authorizationNonce, beforeState
        );
        vm.expectRevert(bytes("authorization from must equal caller"));
        _callAuth(authCase, attacker, authCase.count, authCase.proof);

        vm.warp(block.timestamp + 30 days);
        _callAuth(authCase, authCase.wallet, authCase.count, authCase.proof);
        vm.warp(block.timestamp + 30 days);
        vm.expectRevert(OakSubscription.AuthorizationAlreadyUsed.selector);
        _callAuth(authCase, authCase.wallet, authCase.count, authCase.proof);
    }

    function _prepareAuthCase(uint8 wrapper, bytes32 seed) private returns (AuthCase memory authCase) {
        authCase.wrapper = wrapper;
        authCase.wallet = user;
        authCase.walletKey = USER_KEY;
        authCase.count = COUNT;
        authCase.proof = new bytes32[](0);

        if (wrapper == AUTH_GRANDFATHER) {
            OakSubscription source = _deploy(address(0));
            _approveFor(authCase.wallet, source);
            authCase.count = _subscribeHolder(source, authCase.wallet, keccak256(abi.encode(seed, "source")));
            authCase.target = _deploy(address(source));
            _approveFor(authCase.wallet, authCase.target);
            _setRoot(
                authCase.target, authCase.wallet, authCase.count, address(source), uint64(block.timestamp + 120 days)
            );
        } else {
            authCase.target = _deploy(address(0));
            _approveFor(authCase.wallet, authCase.target);
            if (wrapper == AUTH_RENEW) {
                authCase.count =
                    _subscribeHolder(authCase.target, authCase.wallet, keccak256(abi.encode(seed, "renew")));
            }
        }

        (authCase.note, authCase.noteSignature) =
            _note(authCase.target, authCase.wallet, keccak256(abi.encode(seed, "note")));
        authCase.authorizationNonce = keccak256(abi.encode(seed, "authorization"));
        authCase.authorization =
            _authorization(authCase.walletKey, address(authCase.target), authCase.authorizationNonce);
    }

    function _callAuth(AuthCase memory authCase, address caller, uint256 maxCount, bytes32[] memory proof) private {
        vm.prank(caller);
        if (authCase.wrapper == AUTH_SUBSCRIBE) {
            authCase.target
                .subscribeWithAuthorization(maxCount, authCase.note, authCase.noteSignature, authCase.authorization);
        } else if (authCase.wrapper == AUTH_GRANDFATHER) {
            authCase.target.subscribeGrandfatheredWithAuthorization(authCase.count, proof, authCase.authorization);
        } else {
            authCase.target.renewWithAuthorization(authCase.authorization);
        }
    }

    function _snapshot(OakSubscription target, address wallet, bytes32 noteNonce, bytes32 authorizationNonce)
        private
        view
        returns (StateSnapshot memory state)
    {
        state.plan = target.plan(wallet);
        state.paidUntil = target.paidUntil(wallet);
        state.count = target.signupOakCount(wallet);
        state.hasRecord = target.hasRecord(wallet);
        state.grandfathered = target.grandfathered(wallet);
        state.noteUsed = target.noteUsed(wallet, noteNonce);
        state.authorizationUsed = usdg.authorizationState(wallet, authorizationNonce);
        state.burner = target.burner();
        state.treasury = target.treasury();
        state.targetBalance = usdg.balanceOf(address(target));
        state.walletBalance = usdg.balanceOf(wallet);
        state.burnerBalance = usdg.balanceOf(state.burner);
        state.treasuryBalance = usdg.balanceOf(state.treasury);
        state.oakBalance = oak.balanceOf(wallet);
        state.oakSupply = oak.totalSupply();
    }

    function _assertUnchanged(
        OakSubscription target,
        address wallet,
        bytes32 noteNonce,
        bytes32 authorizationNonce,
        StateSnapshot memory expected
    ) private view {
        StateSnapshot memory actual = _snapshot(target, wallet, noteNonce, authorizationNonce);
        assertEq(actual.plan, expected.plan);
        assertEq(actual.paidUntil, expected.paidUntil);
        assertEq(actual.count, expected.count);
        assertEq(actual.hasRecord, expected.hasRecord);
        assertEq(actual.grandfathered, expected.grandfathered);
        assertEq(actual.noteUsed, expected.noteUsed);
        assertEq(actual.authorizationUsed, expected.authorizationUsed);
        assertEq(actual.burner, expected.burner);
        assertEq(actual.treasury, expected.treasury);
        assertEq(actual.targetBalance, expected.targetBalance);
        assertEq(actual.walletBalance, expected.walletBalance);
        assertEq(actual.burnerBalance, expected.burnerBalance);
        assertEq(actual.treasuryBalance, expected.treasuryBalance);
        assertEq(actual.oakBalance, expected.oakBalance);
        assertEq(actual.oakSupply, expected.oakSupply);
    }

    function _deploy(address previous) private returns (OakSubscription) {
        return new OakSubscription(address(usdg), address(oak), address(oracle), BURNER, TREASURY, SAFE, previous);
    }

    function _fundAndApprove(address wallet, OakSubscription target) private {
        usdg.mint(wallet, 1_000_000_000_000);
        oak.mint(wallet, 1_000_000e18);
        _approveFor(wallet, target);
    }

    function _approveFor(address wallet, OakSubscription target) private {
        vm.startPrank(wallet);
        usdg.approve(address(target), type(uint256).max);
        oak.approve(address(target), type(uint256).max);
        vm.stopPrank();
    }

    function _subscribeHolder(OakSubscription target, address wallet, bytes32 nonce) private returns (uint256 count) {
        (PriceNote memory note, bytes memory signature) = _note(target, wallet, nonce);
        uint256 entryCount;
        vm.prank(wallet);
        (entryCount,) = target.quoteHolder(note, signature);
        vm.prank(wallet);
        target.subscribe(HOLDER, entryCount, 0, note, signature);
        count = target.signupOakCount(wallet);
    }

    function _setRoot(OakSubscription target, address wallet, uint256 count, address source, uint64 deadline) private {
        vm.prank(SAFE);
        target.setGrandfatherRoot(OakMerkle.grandfatherLeaf(wallet, count, source), deadline);
    }

    function _note(OakSubscription target, address wallet, bytes32 nonce)
        private
        view
        returns (PriceNote memory note, bytes memory signature)
    {
        return _noteAt(target, wallet, nonce, OAK_PER_ETH);
    }

    function _noteAt(OakSubscription target, address wallet, bytes32 nonce, uint256 oakPerEth)
        private
        view
        returns (PriceNote memory note, bytes memory signature)
    {
        note = PriceNote({wallet: wallet, oakPerEthE18: oakPerEth, timestamp: uint64(block.timestamp), nonce: nonce});
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, OakPriceNote.digest(note, address(target)));
        signature = abi.encodePacked(r, s, v);
    }

    function _authorization(uint256 fromKey, address to, bytes32 nonce) private view returns (bytes memory) {
        address from = vm.addr(fromKey);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(fromKey, usdg.authorizationDigest(from, to, PRICE, 0, type(uint256).max, nonce));
        return _encodeAuthorization(from, to, nonce, v, r, s);
    }

    function _encodeAuthorization(address from, address to, bytes32 nonce, uint8 v, bytes32 r, bytes32 s)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            LineageUSDG.receiveWithAuthorization.selector, from, to, PRICE, 0, type(uint256).max, nonce, v, r, s
        );
    }

    function _cancelAuthorization(uint256 authorizerKey, bytes32 nonce) private {
        address authorizer = vm.addr(authorizerKey);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authorizerKey, usdg.cancellationDigest(authorizer, nonce));
        usdg.cancelAuthorization(authorizer, nonce, v, r, s);
    }
}
