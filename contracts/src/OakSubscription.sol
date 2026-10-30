// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IOakOracle} from "./interfaces/IOakOracle.sol";
import {IOakSubscription} from "./interfaces/IOakSubscription.sol";
import {IOakSubscriptionErrors} from "./interfaces/IOakSubscriptionErrors.sol";
import {OakMerkle} from "./libraries/OakMerkle.sol";
import {PriceNote} from "./libraries/OakPriceNote.sol";
import {OakPricing} from "./libraries/OakPricing.sol";

interface IOakToken is IERC20 {
    function burnFrom(address account, uint256 amount) external;
}

interface IAuthorizationToken is IERC20 {
    function authorizationState(address authorizer, bytes32 nonce) external view returns (bool);
}

/// @notice Immutable-lineage Oak access subscriptions paid in USDG.
contract OakSubscription is IOakSubscription, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;

    uint8 public constant PLAN_NONE = 0;
    uint8 public constant PLAN_HOLDER = 1;
    uint8 public constant PLAN_NO_HOLD = 2;
    uint8 private constant PHASE_READY = 1;

    uint256 public constant PRICE = 9_000_000;
    uint256 public constant PERIOD = 30 days;
    uint256 public constant PREPAY_CAP = 90 days;
    uint256 public constant SIGNUP_BURN_BPS = 500;
    uint256 public constant GRANDFATHER_WINDOW = 120 days;
    uint8 public constant OAK_DECIMALS = 18;

    bytes4 private constant RECEIVE_WITH_AUTHORIZATION_VRS = bytes4(
        keccak256("receiveWithAuthorization(address,address,uint256,uint256,uint256,bytes32,uint8,bytes32,bytes32)")
    );
    bytes4 private constant RECEIVE_WITH_AUTHORIZATION_BYTES =
        bytes4(keccak256("receiveWithAuthorization(address,address,uint256,uint256,uint256,bytes32,bytes)"));

    IERC20 public immutable usdg;
    IOakToken public immutable oak;
    IOakOracle public immutable oracle;
    address public immutable safe;
    address public immutable override previous;

    address public burner;
    address public treasury;

    mapping(address wallet => uint8 plan_) public override plan;
    mapping(address wallet => uint64 timestamp) public override paidUntil;
    mapping(address wallet => uint256 count) public override signupOakCount;
    mapping(address wallet => bool recorded) public override hasRecord;
    mapping(address wallet => bool used) public override grandfathered;
    mapping(address wallet => mapping(bytes32 nonce => bool used)) public override noteUsed;

    bool public override retired;
    bool public grandfatherRootSet;
    bytes32 public grandfatherRoot;
    uint64 public grandfatherDeadline;

    struct AuthorizationData {
        address from;
        address to;
        uint256 value;
        bytes32 nonce;
    }

    struct Settlement {
        address wallet;
        uint8 plan_;
        uint64 nextPaidUntil;
        uint256 amount;
        uint256 count;
        uint256 oakBurn;
        bool subscription;
        bool grandfather;
    }

    error OnlySafe();
    error ZeroAddress();
    error InvalidPayee();
    error InvalidPlan();
    error InvalidPlanParameters();
    error SubscriptionAlreadyActive();
    error WrongPlan();
    error CountAboveMaximum(uint256 count, uint256 maximum);
    error PriceAboveMaximum(uint256 price, uint256 maximum);
    error InsufficientOak(uint256 balance, uint256 required);
    error PaymentAmountMismatch(uint256 expected, uint256 received);
    error PrepayCapExceeded(uint256 paidUntil, uint256 cap);
    error InvalidAuthorization();
    error AuthorizationAlreadyUsed();
    error NoPredecessor();
    error GrandfatherRootAlreadySet();
    error InvalidGrandfatherRoot();
    error InvalidGrandfatherDeadline();
    error GrandfatherUnavailable();
    error GrandfatherSourceInvalid();
    error InvalidGrandfatherProof();
    error LineageTooDeep();

    event PayeesSet(address burner, address treasury);

    constructor(
        address usdg_,
        address oak_,
        address oracle_,
        address burner_,
        address treasury_,
        address safe_,
        address previous_
    ) {
        if (usdg_ == address(0) || oak_ == address(0) || oracle_ == address(0) || safe_ == address(0)) {
            revert ZeroAddress();
        }
        if (burner_ == address(0) || treasury_ == address(0) || burner_ == address(this) || treasury_ == address(this)) revert InvalidPayee();

        usdg = IERC20(usdg_);
        oak = IOakToken(oak_);
        oracle = IOakOracle(oracle_);
        burner = burner_;
        treasury = treasury_;
        safe = safe_;
        previous = previous_;
    }

    modifier onlySafe() {
        if (msg.sender != safe) revert OnlySafe();
        _;
    }

    function subscribe(uint8 plan_, uint256 maxCount, uint256 maxPrice, PriceNote calldata n, bytes calldata sig)
        external
        override
        nonReentrant
    {
        _requireNotRetired();
        _requireFreshSubscription(msg.sender);
        oracle.syncPhase();

        if (plan_ == PLAN_HOLDER) {
            if (maxPrice != 0) revert InvalidPlanParameters();
            _subscribeHolderAllowance(maxCount, n, sig);
        } else if (plan_ == PLAN_NO_HOLD) {
            if (maxCount != 0) revert InvalidPlanParameters();
            _subscribeNoHoldAllowance(maxPrice, n, sig);
        } else {
            revert InvalidPlan();
        }
    }

    function subscribeWithAuthorization(
        uint256 maxCount,
        PriceNote calldata n,
        bytes calldata sig,
        bytes calldata usdgAuth
    ) external override nonReentrant {
        AuthorizationData memory auth = _decodeAuthorization(usdgAuth);
        _requireAuthorizationCaller(auth);
        _requireNotRetired();
        _requireFreshSubscription(msg.sender);
        oracle.syncPhase();
        _requireHolderReady();
        _requireUnusedNote(n.nonce);

        (uint256 count, uint256 burnAmount) = _quoteHolderReady(n, sig, msg.sender);
        if (count > maxCount) revert CountAboveMaximum(count, maxCount);
        _requireOakBalance(msg.sender, count);

        Settlement memory settlement = Settlement({
            wallet: msg.sender,
            plan_: PLAN_HOLDER,
            nextPaidUntil: _nextPaidUntil(paidUntil[msg.sender]),
            amount: PRICE,
            count: count - burnAmount,
            oakBurn: burnAmount,
            subscription: true,
            grandfather: false
        });

        noteUsed[msg.sender][n.nonce] = true;
        _collectAuthorization(PRICE, auth, usdgAuth);
        _settle(settlement);
    }

    function subscribeGrandfathered(uint256 count, bytes32[] calldata proof) external override nonReentrant {
        _requireNotRetired();
        uint64 nextPaid = _prepareGrandfathering(msg.sender, count, proof);
        _collectAllowance(msg.sender, PRICE);
        _settle(_grandfatherSettlement(msg.sender, count, nextPaid));
    }

    function subscribeGrandfatheredWithAuthorization(uint256 count, bytes32[] calldata proof, bytes calldata usdgAuth)
        external
        override
        nonReentrant
    {
        AuthorizationData memory auth = _decodeAuthorization(usdgAuth);
        _requireAuthorizationCaller(auth);
        _requireNotRetired();
        uint64 nextPaid = _prepareGrandfathering(msg.sender, count, proof);
        _collectAuthorization(PRICE, auth, usdgAuth);
        _settle(_grandfatherSettlement(msg.sender, count, nextPaid));
    }

    function renew() external override nonReentrant {
        _requireNotRetired();
        if (plan[msg.sender] != PLAN_HOLDER) revert WrongPlan();

        Settlement memory settlement = _renewalSettlement(msg.sender, PLAN_HOLDER, PRICE);
        _collectAllowance(msg.sender, PRICE);
        _settle(settlement);
    }

    function renewWithAuthorization(bytes calldata usdgAuth) external override nonReentrant {
        AuthorizationData memory auth = _decodeAuthorization(usdgAuth);
        _requireAuthorizationCaller(auth);
        _requireNotRetired();
        if (plan[msg.sender] != PLAN_HOLDER) revert WrongPlan();

        Settlement memory settlement = _renewalSettlement(msg.sender, PLAN_HOLDER, PRICE);
        _collectAuthorization(PRICE, auth, usdgAuth);
        _settle(settlement);
    }

    function renewNoHold(uint256 maxPrice, PriceNote calldata n, bytes calldata sig) external override nonReentrant {
        _requireNotRetired();
        if (plan[msg.sender] != PLAN_NO_HOLD) revert WrongPlan();

        bool usesNote = oracle.syncPhase() == PHASE_READY;
        if (usesNote) _requireUnusedNote(n.nonce);
        uint256 price = _noHoldPriceForPhase(usesNote, n, sig, msg.sender);
        if (price > maxPrice) revert PriceAboveMaximum(price, maxPrice);

        Settlement memory settlement = _renewalSettlement(msg.sender, PLAN_NO_HOLD, price);
        if (usesNote) noteUsed[msg.sender][n.nonce] = true;
        _collectAllowance(msg.sender, price);
        _settle(settlement);
    }

    function cancel() external override nonReentrant {
        plan[msg.sender] = PLAN_NONE;
        paidUntil[msg.sender] = 0;
        signupOakCount[msg.sender] = 0;
        emit Cancelled(msg.sender, uint64(block.timestamp));
    }

    function retire() external override onlySafe {
        _requireNotRetired();
        retired = true;
        emit Retired(uint64(block.timestamp));
    }

    function setGrandfatherRoot(bytes32 root, uint64 deadline) external override onlySafe {
        if (previous == address(0)) revert NoPredecessor();
        if (grandfatherRootSet) revert GrandfatherRootAlreadySet();
        if (root == bytes32(0)) revert InvalidGrandfatherRoot();
        if (deadline <= block.timestamp || deadline > block.timestamp + GRANDFATHER_WINDOW) {
            revert InvalidGrandfatherDeadline();
        }

        grandfatherRootSet = true;
        grandfatherRoot = root;
        grandfatherDeadline = deadline;
        emit GrandfatherRootSet(root, deadline);
    }

    function setPayees(address burner_, address treasury_) external override onlySafe {
        if (burner_ == address(0) || treasury_ == address(0) || burner_ == address(this) || treasury_ == address(this)) revert InvalidPayee();
        burner = burner_;
        treasury = treasury_;
        emit PayeesSet(burner_, treasury_);
    }

    function sweepToTreasury() external override nonReentrant {
        uint256 amount = usdg.balanceOf(address(this));
        if (amount != 0) usdg.safeTransfer(treasury, amount);
    }

    function expiresAt(address wallet) external view override returns (uint64) {
        return paidUntil[wallet];
    }

    function hasAccess(address wallet) external view override returns (bool) {
        uint8 walletPlan = plan[wallet];
        if (walletPlan == PLAN_NONE || paidUntil[wallet] < block.timestamp) return false;
        if (walletPlan == PLAN_NO_HOLD) return true;
        if (walletPlan == PLAN_HOLDER) return oak.balanceOf(wallet) >= signupOakCount[wallet];
        return false;
    }

    function holderOpen() external view override returns (bool) {
        return oracle.available();
    }

    function quoteHolder(PriceNote calldata n, bytes calldata sig)
        external
        view
        override
        returns (uint256 count, uint256 burnAmount)
    {
        _requireHolderReady();
        return _quoteHolderReady(n, sig, msg.sender);
    }

    function quoteNoHold(PriceNote calldata n, bytes calldata sig) external view override returns (uint256 price) {
        bool ready = oracle.phase() == PHASE_READY;
        return _noHoldPriceForPhase(ready, n, sig, msg.sender);
    }

    function _subscribeHolderAllowance(uint256 maxCount, PriceNote calldata n, bytes calldata sig) private {
        _requireHolderReady();
        _requireUnusedNote(n.nonce);
        (uint256 count, uint256 burnAmount) = _quoteHolderReady(n, sig, msg.sender);
        if (count > maxCount) revert CountAboveMaximum(count, maxCount);
        _requireOakBalance(msg.sender, count);

        Settlement memory settlement = Settlement({
            wallet: msg.sender,
            plan_: PLAN_HOLDER,
            nextPaidUntil: _nextPaidUntil(paidUntil[msg.sender]),
            amount: PRICE,
            count: count - burnAmount,
            oakBurn: burnAmount,
            subscription: true,
            grandfather: false
        });
        noteUsed[msg.sender][n.nonce] = true;
        _collectAllowance(msg.sender, PRICE);
        _settle(settlement);
    }

    function _subscribeNoHoldAllowance(uint256 maxPrice, PriceNote calldata n, bytes calldata sig) private {
        bool usesNote = oracle.phase() == PHASE_READY;
        if (usesNote) _requireUnusedNote(n.nonce);
        uint256 price = _noHoldPriceForPhase(usesNote, n, sig, msg.sender);
        if (price > maxPrice) revert PriceAboveMaximum(price, maxPrice);

        Settlement memory settlement = Settlement({
            wallet: msg.sender,
            plan_: PLAN_NO_HOLD,
            nextPaidUntil: _nextPaidUntil(paidUntil[msg.sender]),
            amount: price,
            count: 0,
            oakBurn: 0,
            subscription: true,
            grandfather: false
        });
        if (usesNote) noteUsed[msg.sender][n.nonce] = true;
        _collectAllowance(msg.sender, price);
        _settle(settlement);
    }

    function _quoteHolderReady(PriceNote calldata n, bytes calldata sig, address wallet)
        private
        view
        returns (uint256 count, uint256 burnAmount)
    {
        (uint256 entry, uint256 oakUsd) = _readyPricing(n, sig, wallet);
        count = OakPricing.requiredCount(entry, oakUsd, OAK_DECIMALS);
        burnAmount = OakPricing.signupBurn(count);
    }

    function _noHoldPriceForPhase(bool ready, PriceNote calldata n, bytes calldata sig, address wallet)
        private
        view
        returns (uint256 price)
    {
        if (!ready) return OakPricing.NOHOLD_FLOOR;
        (uint256 entry,) = _readyPricing(n, sig, wallet);
        return OakPricing.noHoldPriceBase(entry);
    }

    function _readyPricing(PriceNote calldata n, bytes calldata sig, address wallet)
        private
        view
        returns (uint256 entry, uint256 oakUsd)
    {
        uint256 oakPerEthE18 = oracle.verifyNote(n, sig, wallet);
        uint256 ethUsd = oracle.ethUsdE18();
        oakUsd = OakPricing.oakUsdE18(ethUsd, oakPerEthE18);
        uint256 marketCap = OakPricing.marketCapUsdE18(oracle.supplyNet(), oakUsd, OAK_DECIMALS);
        entry = OakPricing.entryUsdE18(marketCap);
    }

    function _prepareGrandfathering(address wallet, uint256 count, bytes32[] calldata proof)
        private
        view
        returns (uint64 nextPaid)
    {
        if (previous == address(0)) revert NoPredecessor();
        if (!grandfatherRootSet || block.timestamp > grandfatherDeadline) revert GrandfatherUnavailable();
        if (hasRecord[wallet] || grandfathered[wallet]) revert GrandfatherUnavailable();

        address source = _newestRecordedAncestor(wallet);
        IOakSubscription sourceSubscription = IOakSubscription(source);
        if (sourceSubscription.plan(wallet) != PLAN_HOLDER || sourceSubscription.signupOakCount(wallet) != count) {
            revert GrandfatherSourceInvalid();
        }

        bytes32 leaf = OakMerkle.grandfatherLeaf(wallet, count, source);
        if (!OakMerkle.verify(grandfatherRoot, leaf, proof)) revert InvalidGrandfatherProof();
        _requireOakBalance(wallet, count);
        return _nextPaidUntil(sourceSubscription.paidUntil(wallet));
    }

    function _newestRecordedAncestor(address wallet) private view returns (address source) {
        source = previous;
        uint256 depth;
        while (source != address(0)) {
            IOakSubscription ancestor = IOakSubscription(source);
            if (ancestor.hasRecord(wallet)) return source;
            source = ancestor.previous();
            unchecked {
                ++depth;
            }
            if (depth == 256) revert LineageTooDeep();
        }
        revert GrandfatherSourceInvalid();
    }

    function _collectAllowance(address from, uint256 amount) private {
        uint256 beforeBalance = usdg.balanceOf(address(this));
        usdg.safeTransferFrom(from, address(this), amount);
        uint256 afterBalance = usdg.balanceOf(address(this));
        _requireExactIncrease(beforeBalance, afterBalance, amount);
    }

    function _collectAuthorization(uint256 amount, AuthorizationData memory auth, bytes calldata usdgAuth) private {
        if (auth.to != address(this) || auth.value != amount) revert InvalidAuthorization();
        if (IAuthorizationToken(address(usdg)).authorizationState(auth.from, auth.nonce)) {
            revert AuthorizationAlreadyUsed();
        }

        uint256 beforeBalance = usdg.balanceOf(address(this));
        address(usdg).functionCall(usdgAuth);
        uint256 afterBalance = usdg.balanceOf(address(this));
        _requireExactIncrease(beforeBalance, afterBalance, amount);
    }

    function _requireExactIncrease(uint256 beforeBalance, uint256 afterBalance, uint256 expected) private pure {
        if (afterBalance < beforeBalance) revert PaymentAmountMismatch(expected, 0);
        uint256 received = afterBalance - beforeBalance;
        if (received != expected) revert PaymentAmountMismatch(expected, received);
    }

    function _settle(Settlement memory settlement) private {
        if (settlement.subscription) {
            plan[settlement.wallet] = settlement.plan_;
            paidUntil[settlement.wallet] = settlement.nextPaidUntil;
            signupOakCount[settlement.wallet] = settlement.count;
            hasRecord[settlement.wallet] = true;
            if (settlement.grandfather) grandfathered[settlement.wallet] = true;
            emit Subscribed(
                settlement.wallet,
                settlement.plan_,
                settlement.nextPaidUntil,
                settlement.count,
                settlement.oakBurn,
                settlement.grandfather
            );
        } else {
            paidUntil[settlement.wallet] = settlement.nextPaidUntil;
            emit Renewed(settlement.wallet, settlement.plan_, settlement.nextPaidUntil, settlement.amount);
        }

        (uint256 burnShare, uint256 treasuryShare) = OakPricing.splitBurn(settlement.amount);
        usdg.safeTransfer(burner, burnShare);
        usdg.safeTransfer(treasury, treasuryShare);

        if (settlement.oakBurn != 0) oak.burnFrom(settlement.wallet, settlement.oakBurn);
    }

    function _grandfatherSettlement(address wallet, uint256 count, uint64 nextPaid)
        private
        pure
        returns (Settlement memory)
    {
        return Settlement({
            wallet: wallet,
            plan_: PLAN_HOLDER,
            nextPaidUntil: nextPaid,
            amount: PRICE,
            count: count,
            oakBurn: 0,
            subscription: true,
            grandfather: true
        });
    }

    function _renewalSettlement(address wallet, uint8 plan_, uint256 amount) private view returns (Settlement memory) {
        return Settlement({
            wallet: wallet,
            plan_: plan_,
            nextPaidUntil: _nextPaidUntil(paidUntil[wallet]),
            amount: amount,
            count: 0,
            oakBurn: 0,
            subscription: false,
            grandfather: false
        });
    }

    function _nextPaidUntil(uint64 currentPaidUntil) private view returns (uint64) {
        uint256 base = currentPaidUntil > block.timestamp ? currentPaidUntil : block.timestamp;
        uint256 nextPaid = base + PERIOD;
        uint256 cap = block.timestamp + PREPAY_CAP;
        if (nextPaid > cap) revert PrepayCapExceeded(nextPaid, cap);
        return uint64(nextPaid);
    }

    function _decodeAuthorization(bytes calldata usdgAuth) private pure returns (AuthorizationData memory auth) {
        if (usdgAuth.length < 4 + 6 * 32) revert InvalidAuthorization();
        bytes4 selector;
        assembly ("memory-safe") {
            selector := calldataload(usdgAuth.offset)
            mstore(auth, calldataload(add(usdgAuth.offset, 4)))
            mstore(add(auth, 0x20), calldataload(add(usdgAuth.offset, 36)))
            mstore(add(auth, 0x40), calldataload(add(usdgAuth.offset, 68)))
            mstore(add(auth, 0x60), calldataload(add(usdgAuth.offset, 164)))
        }
        if (selector != RECEIVE_WITH_AUTHORIZATION_VRS && selector != RECEIVE_WITH_AUTHORIZATION_BYTES) {
            revert InvalidAuthorization();
        }
    }

    function _requireAuthorizationCaller(AuthorizationData memory auth) private view {
        require(auth.from == msg.sender, "authorization from must equal caller");
    }

    function _requireFreshSubscription(address wallet) private view {
        if (plan[wallet] != PLAN_NONE) revert SubscriptionAlreadyActive();
    }

    function _requireHolderReady() private view {
        if (oracle.phase() != PHASE_READY) revert HolderClosed();
    }

    function _requireUnusedNote(bytes32 nonce) private view {
        if (noteUsed[msg.sender][nonce]) revert NoteUsed();
    }

    function _requireOakBalance(address wallet, uint256 required) private view {
        uint256 balance = oak.balanceOf(wallet);
        if (balance < required) revert InsufficientOak(balance, required);
    }

    function _requireNotRetired() private view {
        if (retired) revert IOakSubscriptionErrors.Retired();
    }
}
