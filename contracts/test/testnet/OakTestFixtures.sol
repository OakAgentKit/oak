// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OakOracle} from "../../src/OakOracle.sol";
import {OakSubscription} from "../../src/OakSubscription.sol";
import {OakBurner, IV3SwapRouter, V4ExactInputSingleParams, PoolKey} from "../../src/OakBurner.sol";
import {IOakOracle} from "../../src/interfaces/IOakOracle.sol";
import {OakPriceNote, PriceNote} from "../../src/libraries/OakPriceNote.sol";
import {OakMerkle} from "../../src/libraries/OakMerkle.sol";
import {OakPricing} from "../../src/libraries/OakPricing.sol";
import {LaunchOakToken, IOakLaunchFactory, IOakLaunchRouter} from "../../script/LaunchOakToken.s.sol";

/// @dev All contracts in this file are test fixtures. Minting and synthetic observations are deliberate.
contract OakFixtureToken is ERC20Burnable {
    uint8 private immutable precision;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        precision = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return precision;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract OakFixtureFactory {
    uint8 public phase = 2;

    function memeHook() external pure returns (address) {
        return 0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044;
    }

    function setPhase(uint8 value) external {
        phase = value;
    }

    function realQuoteReserve() external pure returns (uint256) {
        return 100 ether;
    }

    function getLaunchedToken(address token) external view returns (IOakLaunchFactory.Record memory r) {
        r.token = token;
        r.curve = address(this);
        r.poolFee = 0;
        r.tickSpacing = 200;
        r.phase = phase;
        r.exists = true;
    }
}

contract OakFixtureObservations {
    function observe(uint32[] calldata ages)
        external
        pure
        returns (int56[] memory ticks, uint160[] memory liquidities)
    {
        require(ages.length == 2 && ages[0] == 1800 && ages[1] == 0, "wrong observation window");
        ticks = new int56[](2);
        liquidities = new uint160[](2);
        ticks[1] = -200000 * int56(1800);
    }
}

contract OakFixturePoolManager {
    mapping(bytes32 => bytes32) public words;

    function set(bytes32 slot, bytes32 value) external {
        words[slot] = value;
    }

    function extsload(bytes32 slot) external view returns (bytes32) {
        return words[slot];
    }
}

contract OakFixtureWeth is OakFixtureToken("Fixture WETH", "fWETH", 18) {
    receive() external payable {}

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "withdraw failed");
    }
}

/// @dev Install at the burner's fixed addresses ONLY with vm.etch/anvil_setCode locally.
///      Deploying this at a random public-testnet address does not reroute OakBurner.
contract OakFixtureRoute {
    OakOracle public immutable oracle;
    uint256 public outputBps;

    /// @dev Zero retains the fair route. Nonzero models adverse execution only in this fixture.
    function setOutputBps(uint256 bps) external {
        require(bps > 0 && bps <= 10_000, "fixture output range");
        outputBps = bps;
    }

    constructor(OakOracle oracle_) {
        oracle = oracle_;
    }

    function exactInputSingle(IV3SwapRouter.ExactInputSingleParams calldata p) external payable returns (uint256 out) {
        require(IERC20(p.tokenIn).transferFrom(msg.sender, address(this), p.amountIn), "USDG pull");
        out = p.amountIn * 1e30 / oracle.ethUsdE18();
        OakFixtureToken(p.tokenOut).mint(p.recipient, out);
    }

    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable {
        require(deadline >= block.timestamp && keccak256(commands) == keccak256(hex"10"), "route command");
        (bytes memory actions, bytes[] memory params) = abi.decode(inputs[0], (bytes, bytes[]));
        require(keccak256(actions) == keccak256(hex"060c0f"), "route actions");
        V4ExactInputSingleParams memory p = abi.decode(params[0], (V4ExactInputSingleParams));
        require(p.poolKey.currency0 == address(0) && p.zeroForOne && p.minHopPriceX36 == 0, "route shape");
        require(p.amountIn == msg.value, "route value");
        uint256 out = msg.value * oracle.spotOakPerEthE18() / 1e18;
        if (outputBps != 0) out = out * outputBps / 10_000;
        require(out >= p.amountOutMinimum, "minimum output");
        require(IERC20(p.poolKey.currency1).transfer(msg.sender, out), "fixture OAK reserve");
    }
}

interface IOpsSafe {
    function setup(
        address[] calldata owners,
        uint256 threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function getModulesPaginated(address start, uint256 size) external view returns (address[] memory, address);
    function nonce() external view returns (uint256);
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 nonce_
    ) external view returns (bytes32);
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes calldata signatures
    ) external payable returns (bool);
}

interface IOpsSafeFactory {
    function createProxyWithNonce(address singleton, bytes calldata initializer, uint256 salt)
        external
        returns (address);
}

interface IOpsCurve {
    function buy(uint256 quoteIn, uint256 minimum, address recipient) external payable returns (uint256);
    function sweepFees(uint256) external;
}

interface IOpsEscrow {
    function balanceOf(address) external view returns (uint256);
    function claim() external;
}

abstract contract OakOpsFixtureBase is Test {
    address internal constant SINGLETON = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
    address internal constant SAFE_FACTORY = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
    address internal constant FACTORY = 0x7eD598BcEf8bd9Edd8C97A195C6d13f40801EC7e;
    address internal constant ESCROW = 0xd3AFEB2a57f70eF218Aa82451c51B2fb0416Ac9e;
    address internal constant MANAGER = 0x8366a39CC670B4001A1121B8F6A443A643e40951;
    bytes32 internal constant SAFE_HASH = 0x1fe2df852ba3299d6534ef416eefa406e56ced995bca886ab7a553e6d0c5e1c4;
    bytes32 internal constant FACTORY_HASH = 0x50c3cdc4074750a7a974204a716c999edd37482f907608d960b2b025ee0b3317;
    IOpsSafe internal safe;
    uint256[3] internal ownerKeys;
    uint256 internal signerKey;
    address internal signer;
    address internal relayer;
    OakFixtureToken internal oak;
    IERC20 internal usdg;
    OakFixtureFactory internal factory;
    OakFixturePoolManager internal manager;
    OakOracle internal oracle;
    OakBurner internal burner;
    OakSubscription internal subscription;
    uint256 internal noteSequence;

    function _fresh() internal returns (address account, uint256 key) {
        key = vm.randomUint(1, type(uint128).max);
        account = vm.addr(key);
        assertEq(account.code.length, 0, "fresh wallet has code");
        assertEq(vm.getNonce(account), 0, "fresh wallet has nonce");
    }

    function _makeSafe() internal {
        assertEq(SINGLETON.codehash, SAFE_HASH, "Safe singleton pin");
        assertEq(SAFE_FACTORY.codehash, FACTORY_HASH, "Safe proxy factory pin");
        address[] memory owners = new address[](3);
        for (uint256 i; i < 3; ++i) {
            (owners[i], ownerKeys[i]) = _fresh();
        }
        for (uint256 i; i < 3; ++i) {
            for (uint256 j = i + 1; j < 3; ++j) {
                if (owners[i] > owners[j]) {
                    (owners[i], owners[j]) = (owners[j], owners[i]);
                    (ownerKeys[i], ownerKeys[j]) = (ownerKeys[j], ownerKeys[i]);
                }
            }
        }
        bytes memory init = abi.encodeCall(
            IOpsSafe.setup, (owners, 2, address(0), bytes(""), address(0), address(0), 0, payable(address(0)))
        );
        safe = IOpsSafe(IOpsSafeFactory(SAFE_FACTORY).createProxyWithNonce(SINGLETON, init, vm.randomUint()));
        assertEq(safe.getOwners().length, 3);
        assertEq(safe.getThreshold(), 2);
        (address[] memory modules, address next) = safe.getModulesPaginated(address(1), 10);
        assertEq(modules.length, 0);
        assertEq(next, address(1));
        (relayer,) = _fresh();
    }

    function _fixtures(address stable, address admin) internal {
        (signer, signerKey) = _fresh();
        oak = new OakFixtureToken("TEST ONLY Oak", "testOAK", 18);
        usdg = IERC20(stable);
        factory = new OakFixtureFactory();
        manager = new OakFixturePoolManager();
        oracle = new OakOracle(
            address(factory), address(oak), address(manager), address(new OakFixtureObservations()), admin, signer
        );
        manager.set(oracle.spotStorageSlot(), bytes32(uint256(112045541949572279837463876454916)));
        manager.set(bytes32(uint256(oracle.spotStorageSlot()) + 3), bytes32(uint256(1e24)));
        burner = new OakBurner(stable, address(oak), address(oracle), admin, 18);
        subscription = _successor(address(0), admin);
    }

    function _successor(address previous, address admin) internal returns (OakSubscription) {
        return
            new OakSubscription(address(usdg), address(oak), address(oracle), address(burner), admin, admin, previous);
    }

    function _signature(uint256 key, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _safeSignatures(address target, uint256 value, bytes memory data, uint256 count)
        internal
        view
        returns (bytes memory sigs)
    {
        bytes32 digest = safe.getTransactionHash(target, value, data, 0, 0, 0, 0, address(0), address(0), safe.nonce());
        for (uint256 i; i < count; ++i) {
            sigs = bytes.concat(sigs, _signature(ownerKeys[i], digest));
        }
    }

    function _exec(address target, uint256 value, bytes memory data) internal {
        bytes memory sigs = _safeSignatures(target, value, data, 2);
        vm.prank(relayer);
        assertTrue(safe.execTransaction(target, value, data, 0, 0, 0, 0, address(0), payable(address(0)), sigs));
    }

    function _power(address target, uint256 value, bytes memory data, string memory label) internal {
        uint256 beforeNonce = safe.nonce();
        bytes memory one = _safeSignatures(target, value, data, 1);
        vm.expectRevert(bytes("GS020"));
        vm.prank(relayer);
        safe.execTransaction(target, value, data, 0, 0, 0, 0, address(0), payable(address(0)), one);
        assertEq(safe.nonce(), beforeNonce, "one signature changed nonce");
        _exec(target, value, data);
        assertEq(safe.nonce(), beforeNonce + 1);
        emit log_string(string.concat(label, ": one signature GS020; two signatures succeeded"));
    }

    function _failedSafe(address target, bytes memory data) internal {
        bytes memory sigs = _safeSignatures(target, 0, data, 2);
        uint256 beforeNonce = safe.nonce();
        vm.expectRevert(bytes("GS013"));
        vm.prank(relayer);
        safe.execTransaction(target, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), sigs);
        assertEq(safe.nonce(), beforeNonce);
    }

    function _note(address consumer, address wallet, uint256 key, uint256 price)
        internal
        returns (PriceNote memory n, bytes memory sig)
    {
        n = PriceNote(wallet, price, uint64(block.timestamp), bytes32(++noteSequence));
        sig = _signature(key, OakPriceNote.digest(n, consumer));
    }

    function _fund(address wallet, OakSubscription target) internal {
        deal(address(usdg), wallet, 1_000_000_000, false);
        oak.mint(wallet, 1_000_000e18);
        vm.prank(wallet);
        usdg.approve(address(target), 1_000_000_000);
        vm.prank(wallet);
        oak.approve(address(target), 1_000_000e18);
    }

    function _holder(address wallet, OakSubscription target) internal returns (uint256 count) {
        _fund(wallet, target);
        (PriceNote memory n, bytes memory sig) = _note(address(target), wallet, signerKey, oracle.spotOakPerEthE18());
        vm.prank(wallet);
        uint256 burn;
        (count, burn) = target.quoteHolder(n, sig);
        uint256 beforeBalance = oak.balanceOf(wallet);
        vm.prank(wallet);
        target.subscribe(1, count, 0, n, sig);
        assertEq(oak.balanceOf(wallet), beforeBalance - burn);
        count -= burn;
        assertEq(target.signupOakCount(wallet), count, "tracked holding is post-burn");
    }

    function _installLocalRoute() internal {
        OakFixtureWeth weth = new OakFixtureWeth();
        OakFixtureRoute route = new OakFixtureRoute(oracle);
        vm.etch(burner.WETH(), address(weth).code);
        vm.etch(burner.SWAP_ROUTER_02(), address(route).code);
        vm.etch(burner.UNIVERSAL_ROUTER_V2_1_2(), address(route).code);
        vm.deal(burner.WETH(), 100 ether);
        oak.mint(burner.UNIVERSAL_ROUTER_V2_1_2(), 1_000_000e18);
    }

    function _authorizationFlow(address wallet, uint256 key) internal {
        _fund(wallet, subscription);
        (PriceNote memory n, bytes memory sig) =
            _note(address(subscription), wallet, signerKey, oracle.spotOakPerEthE18());
        bytes memory auth = _usdAuthorization(wallet, key);
        vm.prank(wallet);
        (uint256 count, uint256 burn) = subscription.quoteHolder(n, sig);
        // Keep supply/pricing fixed while leaving only the entry count in this wallet.
        uint256 excess = oak.balanceOf(wallet) - count;
        vm.prank(wallet);
        oak.transfer(address(this), excess);
        uint256 beforeSupply = oak.totalSupply();
        uint256 beforeTreasury = usdg.balanceOf(subscription.treasury());
        vm.prank(wallet);
        subscription.subscribeWithAuthorization(type(uint256).max, n, sig, auth);
        assertEq(usdg.balanceOf(address(burner)), 2_250_000);
        assertEq(usdg.balanceOf(subscription.treasury()) - beforeTreasury, 6_750_000);
        assertEq(usdg.balanceOf(address(subscription)), 0);
        assertLt(oak.totalSupply(), beforeSupply);
        assertEq(oak.balanceOf(wallet), count - burn, "entry count alone covers signup burn");
        assertEq(subscription.signupOakCount(wallet), count - burn);
        assertEq(beforeSupply - oak.totalSupply(), burn);
        vm.prank(wallet);
        subscription.cancel();
        // Replay must reach authorization validation, rather than fail the new signup holding check.
        oak.mint(wallet, burn);
        (n, sig) = _note(address(subscription), wallet, signerKey, oracle.spotOakPerEthE18());
        vm.expectRevert(OakSubscription.AuthorizationAlreadyUsed.selector);
        vm.prank(wallet);
        subscription.subscribeWithAuthorization(type(uint256).max, n, sig, auth);
        assertFalse(subscription.noteUsed(n.wallet, n.nonce));
        assertEq(subscription.plan(wallet), 0);
        emit log_string("real USDG EIP-3009: exact split, true signup burn, replay rejected without settlement");
    }

    function _usdAuthorization(address wallet, uint256 key) internal view returns (bytes memory auth) {
        (bool ok, bytes memory domain) = address(usdg).staticcall(abi.encodeWithSignature("DOMAIN_SEPARATOR()"));
        assertTrue(ok);
        bytes32 nonce = keccak256("Task15 EIP3009 single use");
        bytes32 typehash = keccak256(
            "ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                hex"1901",
                abi.decode(domain, (bytes32)),
                keccak256(
                    abi.encode(
                        typehash,
                        wallet,
                        address(subscription),
                        uint256(9_000_000),
                        block.timestamp - 1,
                        block.timestamp + 1 days,
                        nonce
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        auth = abi.encodeWithSignature(
            "receiveWithAuthorization(address,address,uint256,uint256,uint256,bytes32,uint8,bytes32,bytes32)",
            wallet,
            address(subscription),
            uint256(9_000_000),
            block.timestamp - 1,
            block.timestamp + 1 days,
            nonce,
            v,
            r,
            s
        );
    }
}

contract OakOpsMainnetForkTest is OakOpsFixtureBase {
    function setUp() public {
        vm.skip(!vm.envOr("OAK_OPS_FORK", false));
        assertEq(block.chainid, 4663);
        _makeSafe();
        _fixtures(address(new OakFixtureToken("TEST USDG", "testUSDG", 6)), address(safe));
    }

    function test_AllOakSafePowersThresholdAndExactSweepBoundary() public {
        (address payee,) = _fresh();
        _power(address(subscription), 0, abi.encodeCall(subscription.setPayees, (address(burner), payee)), "setPayees");
        assertEq(subscription.treasury(), payee);
        _power(address(subscription), 0, abi.encodeCall(subscription.retire, ()), "retire");
        assertTrue(subscription.retired());
        OakSubscription v2 = _successor(address(subscription), address(safe));
        bytes32 root = keccak256("source-bound root threshold control");
        uint64 deadline = uint64(block.timestamp + 120 days);
        _power(address(v2), 0, abi.encodeCall(v2.setGrandfatherRoot, (root, deadline)), "setGrandfatherRoot");
        assertEq(v2.grandfatherRoot(), root);
        _failedSafe(address(v2), abi.encodeCall(v2.setGrandfatherRoot, (root, deadline)));
        _power(address(oracle), 0, abi.encodeCall(oracle.setPriceSigner, (payee)), "setPriceSigner");
        assertEq(oracle.priceSigner(), payee);
        deal(address(usdg), address(burner), 100_000_000, false);
        _power(address(burner), 0, abi.encodeCall(burner.armSweep, ()), "armSweep");
        uint256 at = burner.armedAt();
        assertEq(burner.armedBalance(), 100_000_000);
        deal(address(usdg), address(burner), 150_000_000, false);
        vm.warp(at + 90 days - 1);
        vm.expectRevert(abi.encodeWithSelector(OakBurner.SweepNotReady.selector, at + 90 days));
        vm.prank(address(safe));
        burner.sweepStuck();
        _failedSafe(address(burner), abi.encodeCall(burner.sweepStuck, ()));
        assertEq(usdg.balanceOf(address(burner)), 150_000_000);
        vm.warp(at + 90 days);
        _power(address(burner), 0, abi.encodeCall(burner.sweepStuck, ()), "sweepStuck at exactly 90 days");
        assertEq(usdg.balanceOf(address(safe)), 100_000_000);
        assertEq(usdg.balanceOf(address(burner)), 50_000_000);
        assertEq(burner.armedAt(), 0);
        _exec(address(burner), 0, abi.encodeCall(burner.armSweep, ()));
        uint256 secondArm = burner.armedAt();
        deal(address(usdg), address(burner), 20_000_000, false);
        vm.warp(secondArm + 90 days);
        _exec(address(burner), 0, abi.encodeCall(burner.sweepStuck, ()));
        assertEq(usdg.balanceOf(address(safe)), 120_000_000, "reduced balance cap");
        assertEq(usdg.balanceOf(address(burner)), 0);
        vm.deal(address(safe), 1 ether);
        _power(payee, 1 ether, "", "treasury ETH");
        assertEq(payee.balance, 1 ether);
        _power(address(usdg), 0, abi.encodeCall(IERC20.transfer, (payee, 100_000_000)), "treasury USDG");
        assertEq(usdg.balanceOf(payee), 100_000_000);
    }

    function test_FreshV2CancelAndV3CannotReviveOlderRecord() public {
        (address wallet,) = _fresh();
        uint256 oldCount = _holder(wallet, subscription);
        _exec(address(subscription), 0, abi.encodeCall(subscription.retire, ()));
        OakSubscription v2 = _successor(address(subscription), address(safe));
        _holder(wallet, v2);
        assertFalse(v2.grandfathered(wallet));
        vm.prank(wallet);
        v2.cancel();
        assertTrue(subscription.hasAccess(wallet));
        assertEq(_authoritative(v2, wallet), address(v2));
        assertFalse(v2.hasAccess(wallet));
        _exec(address(v2), 0, abi.encodeCall(v2.retire, ()));
        OakSubscription v3 = _successor(address(v2), address(safe));
        _exec(
            address(v3),
            0,
            abi.encodeCall(
                v3.setGrandfatherRoot,
                (OakMerkle.grandfatherLeaf(wallet, oldCount, address(subscription)), uint64(block.timestamp + 120 days))
            )
        );
        bytes32[] memory none = new bytes32[](0);
        vm.expectRevert(OakSubscription.GrandfatherSourceInvalid.selector);
        vm.prank(wallet);
        v3.subscribeGrandfathered(oldCount, none);
    }

    function test_SignerRotationBothConsumersGuardPauseAndBurnDisarms() public {
        _installLocalRoute();
        (address wallet,) = _fresh();
        uint256 tracked = _holder(wallet, subscription);
        (address newcomer,) = _fresh();
        _fund(newcomer, subscription);
        (PriceNote memory oldSub, bytes memory oldSubSig) =
            _note(address(subscription), newcomer, signerKey, oracle.spotOakPerEthE18());
        (PriceNote memory oldBurn, bytes memory oldBurnSig) =
            _note(address(burner), address(this), signerKey, oracle.spotOakPerEthE18());
        vm.prank(address(subscription));
        assertEq(oracle.verifyNote(oldSub, oldSubSig, newcomer), oldSub.oakPerEthE18);
        vm.prank(address(burner));
        assertEq(oracle.verifyNote(oldBurn, oldBurnSig, address(0)), oldBurn.oakPerEthE18);
        (address replacement, uint256 replacementKey) = _fresh();
        _power(address(oracle), 0, abi.encodeCall(oracle.setPriceSigner, (replacement)), "signer rotation");
        deal(address(usdg), address(burner), 100_000_000, false);
        vm.expectRevert(IOakOracle.NoteBadSignature.selector);
        vm.prank(newcomer);
        subscription.subscribe(1, type(uint256).max, 0, oldSub, oldSubSig);
        vm.expectRevert(IOakOracle.NoteBadSignature.selector);
        burner.buyAndBurn(1_000_000, oldBurn, oldBurnSig);
        assertFalse(subscription.noteUsed(oldSub.wallet, oldSub.nonce));
        assertFalse(burner.noteUsed(oldBurn.wallet, oldBurn.nonce));
        (PriceNote memory fresh, bytes memory sig) =
            _note(address(subscription), newcomer, replacementKey, oracle.spotOakPerEthE18());
        vm.prank(newcomer);
        subscription.subscribe(1, type(uint256).max, 0, fresh, sig);
        _exec(address(burner), 0, abi.encodeCall(burner.armSweep, ()));
        uint256 disarmAmount = burner.armedBalance() / burner.SWEEP_DISARM_DENOMINATOR();
        if (burner.armedBalance() % burner.SWEEP_DISARM_DENOMINATOR() != 0) ++disarmAmount;
        (fresh, sig) = _note(address(burner), address(this), replacementKey, oracle.spotOakPerEthE18());
        burner.buyAndBurn(disarmAmount, fresh, sig);
        assertEq(burner.armedAt(), 0);
        assertEq(burner.armedBalance(), 0);
        vm.warp(block.timestamp + 90 days);
        _failedSafe(address(burner), abi.encodeCall(burner.sweepStuck, ()));
        // The Safe selects a signer controlled by one of its owners; this grants no guard bypass.
        address controlled = vm.addr(ownerKeys[0]);
        _exec(address(oracle), 0, abi.encodeCall(oracle.setPriceSigner, (controlled)));
        (fresh, sig) = _note(address(burner), address(this), ownerKeys[0], oracle.spotOakPerEthE18() * 2);
        vm.expectPartialRevert(IOakOracle.NoteOutsideGuard.selector);
        burner.buyAndBurn(1_000_000, fresh, sig);
        assertFalse(burner.noteUsed(fresh.wallet, fresh.nonce));
        (fresh, sig) = _note(address(burner), address(this), ownerKeys[0], oracle.spotOakPerEthE18());
        burner.buyAndBurn(1_000_000, fresh, sig);
        _exec(address(oracle), 0, abi.encodeCall(oracle.setPriceSigner, (address(0))));
        (fresh, sig) = _note(address(burner), address(this), ownerKeys[0], oracle.spotOakPerEthE18());
        vm.expectRevert(IOakOracle.NoteBadSignature.selector);
        burner.buyAndBurn(1_000_000, fresh, sig);
        vm.prank(wallet);
        subscription.renew();
        assertEq(subscription.signupOakCount(wallet), tracked);
        assertTrue(subscription.hasAccess(wallet));
        factory.setPhase(0);
        (address floorWallet,) = _fresh();
        _fund(floorWallet, subscription);
        PriceNote memory empty;
        vm.prank(floorWallet);
        subscription.subscribe(2, 0, 12_333_333, empty, "");
        assertEq(subscription.plan(floorWallet), 2);
        emit log_string("rotation rejects old notes in both consumers; controlled signer guard holds; zero pause preserves renew/floor; burn disarms");
    }

    function test_BurnerPriceAgreementRejectsLaggingNoteBeforeBalanceSpend() public {
        _installLocalRoute();
        uint256 cap = oracle.liquidityUsdgE6() / 200;
        uint256 chunk = 1_000_000;
        assertGe(cap, chunk);
        uint256 spot = oracle.spotOakPerEthE18();
        uint256 low = spot - spot / 2;
        deal(address(usdg), address(burner), 3 * chunk, false);
        (PriceNote memory n, bytes memory sig) = _note(address(burner), address(this), signerKey, low);
        vm.expectRevert(abi.encodeWithSelector(OakBurner.ChunkTooLarge.selector, cap + 1, cap));
        burner.buyAndBurn(cap + 1, n, sig);
        assertEq(usdg.balanceOf(address(burner)), 3 * chunk);
        assertFalse(burner.noteUsed(n.wallet, n.nonce));
        (n, sig) = _note(address(burner), address(this), signerKey, low - 1);
        vm.expectPartialRevert(IOakOracle.NoteOutsideGuard.selector);
        burner.buyAndBurn(chunk, n, sig);
        assertEq(usdg.balanceOf(address(burner)), 3 * chunk);
        assertFalse(burner.noteUsed(n.wallet, n.nonce));

        (n, sig) = _note(address(burner), address(this), signerKey, low);
        vm.expectRevert(abi.encodeWithSelector(OakBurner.NoteSpotMismatch.selector, spot, low));
        burner.buyAndBurn(chunk, n, sig);
        assertEq(usdg.balanceOf(address(burner)), 3 * chunk);
        assertFalse(burner.noteUsed(n.wallet, n.nonce));
        emit log_named_uint("chunk cap USDG base units", cap);
        emit log_string("Burner rejects a signed note outside its 10 percent spot agreement before spending USDG.");
    }

    struct Population {
        address active;
        address lapsed;
        address nohold;
        address cancelled;
        uint256 activeCount;
        uint256 lapsedCount;
    }

    function test_RedeployPopulationLiveCarrySourceBindingAndNoResurrection() public {
        Population memory population;
        vm.recordLogs();
        (population.active,) = _fresh();
        (population.lapsed,) = _fresh();
        (population.nohold,) = _fresh();
        (population.cancelled,) = _fresh();
        population.lapsedCount = _holder(population.lapsed, subscription);
        vm.warp(block.timestamp + 31 days);
        population.activeCount = _holder(population.active, subscription);
        _holder(population.cancelled, subscription);
        vm.prank(population.cancelled);
        subscription.cancel();
        _fund(population.nohold, subscription);
        factory.setPhase(0);
        PriceNote memory empty;
        vm.prank(population.nohold);
        subscription.subscribe(2, 0, 12_333_333, empty, "");
        factory.setPhase(2);
        _exec(address(subscription), 0, abi.encodeCall(subscription.retire, ()));

        assertTrue(subscription.hasAccess(population.active));
        assertFalse(subscription.hasAccess(population.lapsed));
        vm.expectRevert(bytes4(keccak256("Retired()")));
        vm.prank(population.active);
        subscription.renew();
        OakSubscription v2 = _successor(address(subscription), address(safe));
        bytes32 a = OakMerkle.grandfatherLeaf(population.active, population.activeCount, address(subscription));
        bytes32 b = OakMerkle.grandfatherLeaf(population.lapsed, population.lapsedCount, address(subscription));
        bytes32 root = a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
        _exportPopulation(vm.getRecordedLogs(), root, population.active);
        _exec(address(v2), 0, abi.encodeCall(v2.setGrandfatherRoot, (root, uint64(block.timestamp + 120 days))));
        assertEq(v2.previous(), address(subscription));
        uint256 supply = oak.totalSupply();
        uint64 paid = subscription.paidUntil(population.active);
        _fund(population.active, v2);
        _fund(population.lapsed, v2);
        supply = oak.totalSupply();
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = b;
        vm.prank(population.active);
        v2.subscribeGrandfathered(population.activeCount, proof);
        assertEq(v2.paidUntil(population.active), paid + 30 days);
        assertEq(v2.signupOakCount(population.active), population.activeCount);
        proof[0] = a;
        vm.prank(population.lapsed);
        v2.subscribeGrandfathered(population.lapsedCount, proof);
        assertEq(v2.paidUntil(population.lapsed), block.timestamp + 30 days);
        assertEq(oak.totalSupply(), supply);
        bytes32[] memory none = new bytes32[](0);
        vm.expectRevert(OakSubscription.GrandfatherSourceInvalid.selector);
        vm.prank(population.cancelled);
        v2.subscribeGrandfathered(0, none);
        vm.expectRevert(OakSubscription.GrandfatherSourceInvalid.selector);
        vm.prank(population.nohold);
        v2.subscribeGrandfathered(0, none);
        vm.prank(population.active);
        v2.cancel();
        assertTrue(subscription.hasAccess(population.active));
        assertEq(_authoritative(v2, population.active), address(v2));
        assertFalse(v2.hasAccess(population.active));
        // Retired records remain readable and cancellable.
        vm.prank(population.active);
        subscription.cancel();
        assertEq(subscription.plan(population.active), 0);
        assertTrue(subscription.hasRecord(population.active));
        vm.warp(subscription.paidUntil(population.nohold));
        _fund(population.nohold, v2);
        factory.setPhase(0);
        vm.prank(population.nohold);
        v2.subscribe(2, 0, 12_333_333, empty, "");
        assertFalse(v2.grandfathered(population.nohold));
        assertEq(v2.signupOakCount(population.nohold), 0);
        emit log_string("retired population: active/lapsed carry original count/time without note/burn; nohold fresh when due; cancelled excluded; no resurrection");
    }

    function test_V3BeforeMigrationFindsNewestRecordedAncestorAndRejectsWrongSource() public {
        (address wallet,) = _fresh();
        uint256 count = _holder(wallet, subscription);
        _exec(address(subscription), 0, abi.encodeCall(subscription.retire, ()));
        OakSubscription v2 = _successor(address(subscription), address(safe));
        _exec(address(v2), 0, abi.encodeCall(v2.retire, ()));
        OakSubscription wrong = _successor(address(v2), address(safe));
        _exec(
            address(wrong),
            0,
            abi.encodeCall(
                wrong.setGrandfatherRoot,
                (OakMerkle.grandfatherLeaf(wallet, count, address(v2)), uint64(block.timestamp + 120 days))
            )
        );
        _fund(wallet, wrong);
        bytes32[] memory none = new bytes32[](0);
        vm.expectRevert(OakSubscription.InvalidGrandfatherProof.selector);
        vm.prank(wallet);
        wrong.subscribeGrandfathered(count, none);
        OakSubscription v3 = _successor(address(v2), address(safe));
        _exec(
            address(v3),
            0,
            abi.encodeCall(
                v3.setGrandfatherRoot,
                (OakMerkle.grandfatherLeaf(wallet, count, address(subscription)), uint64(block.timestamp + 120 days))
            )
        );
        _fund(wallet, v3);
        uint256 supply = oak.totalSupply();
        vm.prank(wallet);
        v3.subscribeGrandfathered(count, none);
        assertEq(v3.signupOakCount(wallet), count);
        assertEq(oak.totalSupply(), supply);
        vm.prank(wallet);
        v3.cancel();
        assertEq(_authoritative(v3, wallet), address(v3));
        assertFalse(v3.hasAccess(wallet));
        emit log_string("v1 -> v2 -> v3 before migration: v1 source accepted, wrong v2 source rejected; cancellation remains authoritative");
    }

    function _authoritative(OakSubscription newest, address wallet) internal view returns (address) {
        while (!newest.hasRecord(wallet) && newest.previous() != address(0)) newest = OakSubscription(newest.previous());
        return address(newest);
    }

    function _exportPopulation(Vm.Log[] memory logs, bytes32 root, address active) internal {
        string memory events = "[";
        bool comma;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(subscription)) continue;
            if (comma) events = string.concat(events, ",");
            comma = true;
            events = string.concat(
                events,
                '{"address":"',
                vm.toString(logs[i].emitter),
                '","blockNumber":"',
                vm.toString(block.number),
                '","logIndex":',
                vm.toString(i),
                ',"topics":['
            );
            for (uint256 j; j < logs[i].topics.length; ++j) {
                if (j > 0) events = string.concat(events, ",");
                events = string.concat(events, '"', vm.toString(logs[i].topics[j]), '"');
            }
            events = string.concat(events, '],"data":"', vm.toString(logs[i].data), '"}');
        }
        emit log_string(string.concat(
                'MIGRATION_JSON:{"source":"',
                vm.toString(address(subscription)),
                '","active":"',
                vm.toString(active),
                '","finalizedBlock":"',
                vm.toString(block.number),
                '","now":"',
                vm.toString(block.timestamp),
                '","root":"',
                vm.toString(root),
                '","events":',
                events,
                "]}"
            ));
    }

    function test_ProductionUsdgPinsAndRealAuthorization() public {
        address stable = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address implementation = address(uint160(uint256(vm.load(stable, slot))));
        assertEq(implementation.codehash, 0x3a551ac5c744af57e68a1d1431ac403c0f516ffd7d224a75746aee11fc4f3baf);
        (bool ok, bytes memory result) =
            stable.staticcall(abi.encodeWithSignature("getFacet(bytes4)", bytes4(0xef55bec6)));
        assertTrue(ok);
        address facet = abi.decode(result, (address));
        assertEq(facet.codehash, 0x2512bf74f82939b5f4ac8f48057e4903fc53c894c7415228c3f4d5c8685a9f06);
        _fixtures(stable, address(safe));
        (address wallet, uint256 key) = _fresh();
        _authorizationFlow(wallet, key);
    }

    function _launch() internal returns (IOakLaunchFactory.Record memory record, address launcher) {
        (launcher,) = _fresh();
        vm.deal(launcher, 20 ether);
        LaunchOakToken script = new LaunchOakToken();
        IOakLaunchFactory.Params memory p = IOakLaunchFactory.Params(
            "Oak Fork Rehearsal",
            "OAKTEST",
            "test only",
            "",
            IOakLaunchFactory.Metadata("", "", "", "", ""),
            launcher,
            100,
            false,
            script.ECONOMICS(),
            bytes32(vm.randomUint())
        );
        uint256 fee = IOakLaunchFactory(FACTORY).launchFee();
        (bytes memory data, uint256 value) = script.prepare(p, 0.1 ether, 1, fee);
        assertEq(bytes4(data), bytes4(0xf85f8e41));
        assertEq(value, fee + 0.1 ether);
        _directFactoryControl(p, launcher, fee);
        record = _launchRouter(launcher, data, value);
        vm.prank(launcher);
        IOakLaunchFactory(FACTORY).transferCreatorFeeRecipient(record.token, address(safe));
        assertEq(IOakLaunchFactory(FACTORY).getLaunchedToken(record.token).creatorFeeRecipient, address(safe));
        vm.expectRevert(bytes4(0xb9f93944));
        vm.prank(launcher);
        IOakLaunchFactory(FACTORY).transferCreatorFeeRecipient(record.token, launcher);
    }

    function _launchRouter(address launcher, bytes memory data, uint256 value)
        internal
        returns (IOakLaunchFactory.Record memory record)
    {
        vm.recordLogs();
        uint256 beforeBalance = launcher.balance;
        address router = 0xe33E9E479dF8802cb0866d5d05258bEc4cF62948;
        vm.prank(launcher, launcher);
        (bool ok, bytes memory output) = router.call{value: value}(data);
        assertTrue(ok, "launch router failed");
        (address token, address curve, uint256 tokens) = abi.decode(output, (address, address, uint256));
        assertGt(tokens, 0);
        assertGt(token.code.length, 0);
        assertEq(beforeBalance - launcher.balance, value);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool emitted;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == FACTORY
                    && logs[i].topics[0] == keccak256("TokenLaunched(address,address,address,address,uint256,uint256)")
            ) emitted = true;
        }
        assertTrue(emitted, "TokenLaunched receipt missing");
        record = IOakLaunchFactory(FACTORY).getLaunchedToken(token);
        assertEq(record.curve, curve);
        assertEq(record.deployer, launcher);
        assertEq(record.creatorFeeRecipient, launcher);
        assertEq(record.creatorTaxBps, 100);
        assertFalse(record.buybackEnabled);
        assertEq(record.pairToken, address(0));
        emit log_named_uint("exact launch value wei", value);
        emit log_named_address("fork launched token", token);
    }

    function _directFactoryControl(IOakLaunchFactory.Params memory p, address launcher, uint256 fee) internal {
        uint256 snapshot = vm.snapshotState();
        vm.prank(launcher, launcher);
        (bool direct, bytes memory output) =
            FACTORY.call{value: fee}(abi.encodeWithSelector(bytes4(0xf35abbcf), p, uint256(0), address(0)));
        assertTrue(direct, "measured direct-factory behavior changed: review");
        address token = abi.decode(output, (address));
        assertGt(token.code.length, 0);
        IOakLaunchFactory.Record memory r = IOakLaunchFactory(FACTORY).getLaunchedToken(token);
        assertTrue(r.exists, "direct launch record missing");
        assertEq(r.creatorFeeRecipient, launcher);
        assertTrue(vm.revertToState(snapshot), "snapshot restore failed");
        // A real rejection control, distinct from the packet's direct-factory rejection premise.
        p.expectedEconomics = keccak256("intentionally wrong nonzero economics");
        vm.prank(launcher, launcher);
        (bool bad, bytes memory reason) =
            FACTORY.call{value: fee}(abi.encodeWithSelector(bytes4(0xf35abbcf), p, uint256(0), address(0)));
        assertFalse(bad, "wrong nonzero economics accepted");
        assertEq(bytes4(reason), bytes4(0xecb27319));
        emit log_string("PREMISE COUNTEREXAMPLE: correct direct factory launch succeeds, creates code and recipient record; router remains required operational path");
        emit log_named_bytes("wrong-economics rejection control", reason);
    }

    function test_RealPonsLaunchFeeSweepsSafeClaimAndRecipientTransfer() public {
        (IOakLaunchFactory.Record memory record, address launcher) = _launch();
        vm.warp(block.timestamp + 10);
        vm.prank(launcher, launcher);
        IOpsCurve(record.curve).buy{value: 1 ether}(1 ether, 1, launcher);
        uint256 beforeCredit = IOpsEscrow(ESCROW).balanceOf(address(safe));
        _power(record.curve, 0, abi.encodeCall(IOpsCurve.sweepFees, (0)), "Pons recipient curve sweep");
        uint256 credit = IOpsEscrow(ESCROW).balanceOf(address(safe));
        assertEq(credit - beforeCredit, 0.0187 ether, "all 1.7 percent of 1.1 ETH");
        (address stranger,) = _fresh();
        vm.expectRevert(bytes4(0xc2caa2a6));
        vm.prank(stranger);
        IOpsEscrow(ESCROW).claim();
        assertEq(IOpsEscrow(ESCROW).balanceOf(address(safe)), credit);
        uint256 beforeEth = address(safe).balance;
        _power(ESCROW, 0, abi.encodeCall(IOpsEscrow.claim, ()), "Pons escrow claim");
        assertEq(address(safe).balance - beforeEth, credit);
        assertEq(IOpsEscrow(ESCROW).balanceOf(address(safe)), 0);
        uint256 nonce = safe.nonce();
        _claimIfPositive();
        assertEq(safe.nonce(), nonce, "empty escrow sent claim");
        _power(
            FACTORY,
            0,
            abi.encodeCall(IOakLaunchFactory.transferCreatorFeeRecipient, (record.token, stranger)),
            "Pons recipient transfer"
        );
        assertEq(IOakLaunchFactory(FACTORY).getLaunchedToken(record.token).creatorFeeRecipient, stranger);
        emit log_named_uint("creator ETH delivered to Safe", credit);
    }

    function _claimIfPositive() internal {
        if (IOpsEscrow(ESCROW).balanceOf(address(safe)) > 0) _exec(ESCROW, 0, abi.encodeCall(IOpsEscrow.claim, ()));
    }

    function test_PonsPendingTokenFeesSkipSweepClaimAlreadyPositiveEscrow() public {
        (IOakLaunchFactory.Record memory record, address launcher) = _launch();
        vm.warp(block.timestamp + 10);
        vm.prank(launcher, launcher);
        IOpsCurve(record.curve).buy{value: 6 ether}(6 ether, 1, launcher);
        (bool ok,) = FACTORY.call(abi.encodeWithSignature("createGraduatedPool(address)", record.token));
        assertTrue(ok);
        assertEq(IOakLaunchFactory(FACTORY).getLaunchedToken(record.token).phase, 2);
        _ethSideSweep(record.token, launcher);
        PoolKey memory key = PoolKey(address(0), record.token, 0, 200, burner.PONS_HOOK());
        V4ExactInputSingleParams memory swap = V4ExactInputSingleParams(key, true, uint128(0.01 ether), 1, 0, "");
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(swap);
        params[1] = abi.encode(address(0), uint256(0.01 ether));
        params[2] = abi.encode(record.token, uint256(1));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(hex"060c0f", params);
        vm.deal(address(this), 1 ether);
        (ok,) = burner.UNIVERSAL_ROUTER_V2_1_2().call{value: 0.01 ether}(
            abi.encodeWithSignature("execute(bytes,bytes[],uint256)", hex"10", inputs, block.timestamp)
        );
        assertTrue(ok, "real v4 buy failed");
        bytes32 pool = keccak256(abi.encode(key));
        bytes memory sweep = abi.encodeWithSignature("sweepPoolFees(bytes32,uint256,uint256)", pool, 0, 0);
        address hook = burner.PONS_HOOK();
        (bool pendingOk, bytes memory pending) =
            hook.staticcall(abi.encodeWithSignature("pendingFees(bytes32,address)", pool, record.token));
        assertTrue(pendingOk);
        assertGt(abi.decode(pending, (uint256)), 0);
        vm.prank(address(safe));
        (bool swept, bytes memory reason) = hook.call(sweep);
        assertFalse(swept);
        assertEq(reason, abi.encodePacked(bytes4(0x31cdb504)));
        uint256 credit = IOpsEscrow(ESCROW).balanceOf(address(safe));
        assertGt(credit, 0);
        uint256 beforeEth = address(safe).balance;
        _claimIfPositive();
        assertEq(address(safe).balance - beforeEth, credit);
        emit log_string("Skip InternalSwapRequiresOperator: token-side fees pending Pons keeper; positive existing escrow claimed by Safe");
    }

    function _ethSideSweep(address token, address launcher) internal {
        address permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        address router = burner.UNIVERSAL_ROUTER_V2_1_2();
        address hook = burner.PONS_HOOK();
        PoolKey memory key = PoolKey(address(0), token, 0, 200, hook);
        uint256 amount = 1e24;
        vm.startPrank(launcher, launcher);
        IERC20(token).approve(permit2, amount);
        (bool approved,) = permit2.call(
            abi.encodeWithSignature(
                "approve(address,address,uint160,uint48)",
                token,
                router,
                uint160(amount),
                uint48(block.timestamp + 1 days)
            )
        );
        assertTrue(approved);
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(V4ExactInputSingleParams(key, false, uint128(amount), 1, 0, ""));
        params[1] = abi.encode(token, amount);
        params[2] = abi.encode(address(0), uint256(1));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(hex"060c0f", params);
        (bool sold,) =
            router.call(abi.encodeWithSignature("execute(bytes,bytes[],uint256)", hex"10", inputs, block.timestamp));
        vm.stopPrank();
        assertTrue(sold, "real v4 sell failed");
        uint256 beforeCredit = IOpsEscrow(ESCROW).balanceOf(address(safe));
        _power(
            hook,
            0,
            abi.encodeWithSignature("sweepPoolFees(bytes32,uint256,uint256)", keccak256(abi.encode(key)), 0, 0),
            "Pons recipient ETH-side pool sweep"
        );
        assertGt(IOpsEscrow(ESCROW).balanceOf(address(safe)), beforeCredit);
    }
}

contract OakOpsTestnetForkTest is OakOpsFixtureBase {
    function setUp() public {
        vm.skip(!vm.envOr("OAK_OPS_FORK", false));
        assertEq(block.chainid, 46630);
        _makeSafe();
        _fixtures(0x7E955252E15c84f5768B83c41a71F9eba181802F, address(safe));
    }

    function test_RealTestUsdgAuthorizationAndRealManagerRead() public {
        assertGt(MANAGER.code.length, 0);
        (bool ok, bytes memory result) = MANAGER.staticcall(abi.encodeWithSignature("extsload(bytes32)", bytes32(0)));
        assertTrue(ok);
        assertEq(result.length, 32);
        (address empty,) = _fresh();
        (ok, result) = empty.staticcall(abi.encodeWithSignature("extsload(bytes32)", bytes32(0)));
        assertTrue(ok);
        assertEq(result.length, 0, "empty-code negative control");
        (address wallet, uint256 key) = _fresh();
        _authorizationFlow(wallet, key);
        _installLocalRoute();
        uint256 beforeSupply = oak.totalSupply();
        (PriceNote memory n, bytes memory sig) =
            _note(address(burner), address(this), signerKey, oracle.spotOakPerEthE18());
        burner.buyAndBurn(1_000_000, n, sig);
        assertLt(oak.totalSupply(), beforeSupply);
        assertEq(usdg.balanceOf(address(burner)), 1_250_000);
        assertTrue(burner.noteUsed(n.wallet, n.nonce));
        emit log_string("46630: real USDG and PoolManager; OAK/factory/observations synthetic; public-testnet burner route NOT proven");
    }
}
