// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IOakOracle} from "../src/interfaces/IOakOracle.sol";
import {IPons, IPonsFactoryView, PonsLaunchRecord} from "../src/interfaces/IPons.sol";
import {PriceNote, OakPriceNote} from "../src/libraries/OakPriceNote.sol";
import {OakOracle, OakTickMath} from "../src/OakOracle.sol";
import {DeployOracle} from "../script/DeployOracle.s.sol";

contract MockPonsFactory {
    address public memeHook = 0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044;

    /// @dev The decoded getLaunchedToken tuple from recorded Pons launch observations.
    struct LaunchedToken {
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

    LaunchedToken internal launched;

    function setRecord(address token_, address curve_, uint8 phase_) external {
        launched.token = token_;
        launched.curve = curve_;
        launched.poolFee = 0;
        launched.tickSpacing = 200;
        launched.phase = phase_;
        launched.exists = true;
    }

    function setMemeHook(address hook) external {
        memeHook = hook;
    }

    function setPhase(uint8 phase_) external {
        launched.phase = phase_;
    }

    function setLaunched(LaunchedToken calldata record) external {
        launched = record;
    }

    function getLaunchedToken(address) external view returns (LaunchedToken memory) {
        return launched;
    }
}

/// @dev Replays one recorded getLaunchedToken return verbatim, and only for the recorded calldata.
contract RecordedPonsFactory {
    bytes internal recordedCalldata;
    bytes internal recordedReturn;

    function load(bytes calldata calldata_, bytes calldata return_) external {
        recordedCalldata = calldata_;
        recordedReturn = return_;
    }

    function memeHook() external pure returns (address) {
        return 0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        require(keccak256(input) == keccak256(recordedCalldata), "UNRECORDED_CALL");
        return recordedReturn;
    }
}

contract MockPoolManager {
    mapping(bytes32 slot => bytes32 value) internal words;

    function setWord(bytes32 slot, bytes32 value) external {
        words[slot] = value;
    }

    function extsload(bytes32 slot) external view returns (bytes32) {
        return words[slot];
    }
}

contract MockObservePool {
    int56 internal first;
    int56 internal second;
    uint8 internal revertMode;

    function setCumulatives(int56 first_, int56 second_) external {
        first = first_;
        second = second_;
        revertMode = 0;
    }

    function setRevertMode(uint8 mode) external {
        revertMode = mode;
    }

    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        require(secondsAgos.length == 2 && secondsAgos[0] == 1800 && secondsAgos[1] == 0, "WINDOW");
        if (revertMode == 1) revert("OLD");
        if (revertMode == 2) revert("I");
        tickCumulatives = new int56[](2);
        secondsPerLiquidityCumulativeX128s = new uint160[](2);
        tickCumulatives[0] = first;
        tickCumulatives[1] = second;
    }
}

contract EmptyReturnTarget {
    fallback() external {}
}

contract FacetNotFoundTarget {
    fallback() external {
        bytes4 selector = 0x800ab12c;
        assembly ("memory-safe") {
            mstore(0, selector)
            revert(0, 4)
        }
    }
}

contract MockCurve {
    uint256 internal reserve;

    function setRealQuoteReserve(uint256 reserve_) external {
        reserve = reserve_;
    }

    function realQuoteReserve() external view returns (uint256) {
        return reserve;
    }
}

contract MockOakToken {
    uint256 internal supply;
    mapping(address account => uint256 balance) internal balances;

    constructor(uint256 supply_) {
        supply = supply_;
        balances[msg.sender] = supply_;
    }

    function totalSupply() external view returns (uint256) {
        return supply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function burn(uint256 amount) external {
        balances[msg.sender] -= amount;
        supply -= amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balances[msg.sender] -= amount;
        balances[to] += amount;
        return true;
    }
}

contract OakOracleTest is Test {
    using stdJson for string;

    uint256 internal constant SIGNER_KEY = 0xA11CE;
    uint256 internal constant NEXT_SIGNER_KEY = 0xB0B;
    uint256 internal constant BAD_SIGNER_KEY = 0xBAD;
    uint256 internal constant NOW = 2_000_000_000;
    uint256 internal constant Q96 = 1 << 96;

    address internal constant SAFE = address(0x5AFE);
    address internal constant WALLET = address(0x1111);
    address internal constant OTHER_WALLET = address(0x2222);
    address internal constant CONSUMER = address(0xC0115E);
    address internal constant OTHER_CONSUMER = address(0xC0115F);
    address internal constant DEAD = address(0xdead);
    address internal constant ETH_USDG_POOL = 0x52e65B17fB6E5BA00Ed806f37Afcd2DaA50271Ca;
    address internal constant PONS_HOOK = 0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044;
    uint256 internal constant ETH_USDG_BLOCK = 100_307_735;

    // Recorded before/after graduation fixture values:
    // /localForkFollowup/measurement/reads/{curveBefore,curveAfterFinish,curveAfterGraduation}.
    address internal constant RECORDED_COIN = 0xc8379941a31AcE4f2F849eBb0d73ECb6c456CDBf;
    address internal constant RECORDED_CURVE = 0x3dBd74547Fdeda7794a37436e8CcEcdBD489d047;
    address internal constant RECORDED_DEPLOYER = 0x71347B7D57233d5B078ce0538eAcc0522052b3A1;
    bytes32 internal constant RECORDED_POOL_ID = 0xaae49f68d1357471243db99c3749592820f5c7bae7b195628fbf7200b288904d;
    // curveBefore, block 100469450
    bytes internal constant PHASE0_RECORD =
        hex"000000000000000000000000c8379941a31ace4f2f849ebb0d73ecb6c456cdbf0000000000000000000000003dbd74547fdeda7794a37436e8ccecdbd489d04700000000000000000000000071347b7d57233d5b078ce0538eacc0522052b3a100000000000000000000000071347b7d57233d5b078ce0538eacc0522052b3a100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a4965bf58a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c800000000000000000000000000000000000000000000000000000000000000c8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001";
    // curveAfterFinish, block 100469451
    bytes internal constant PHASE1_RECORD =
        hex"000000000000000000000000c8379941a31ace4f2f849ebb0d73ecb6c456cdbf0000000000000000000000003dbd74547fdeda7794a37436e8ccecdbd489d04700000000000000000000000071347b7d57233d5b078ce0538eacc0522052b3a100000000000000000000000071347b7d57233d5b078ce0538eacc0522052b3a100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a4965bf58a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c800000000000000000000000000000000000000000000000000000000000000c8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000003a4965bf58a40018000000000000000000000000000000000000000000ec565a76cddb7f1db6db6d000000000000000000000000000000000000000000000000000000006ae28ac00000000000000000000000000000000000000000000000000000000000000001";
    // curveAfterGraduation, block 100469452
    bytes internal constant PHASE2_RECORD =
        hex"000000000000000000000000c8379941a31ace4f2f849ebb0d73ecb6c456cdbf0000000000000000000000003dbd74547fdeda7794a37436e8ccecdbd489d04700000000000000000000000071347b7d57233d5b078ce0538eacc0522052b3a100000000000000000000000071347b7d57233d5b078ce0538eacc0522052b3a100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a4965bf58a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c800000000000000000000000000000000000000000000000000000000000000c8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001";

    bytes32 internal constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant NAME_HASH = keccak256("OakPriceNote");

    string internal vectors;
    MockPonsFactory internal factory;
    MockPoolManager internal poolManager;
    MockObservePool internal ethPool;
    MockCurve internal curve;
    MockOakToken internal oak;
    OakOracle internal oracle;

    function setUp() public {
        vectors = vm.readFile("test/vectors.json");
        factory = new MockPonsFactory();
        poolManager = new MockPoolManager();
        ethPool = new MockObservePool();
        curve = new MockCurve();
        oak = new MockOakToken(1e27);
        factory.setRecord(address(oak), address(curve), 2);
        ethPool.setCumulatives(
            int56(_i(".oracle.ethUsd.tickCumulatives[0]")), int56(_i(".oracle.ethUsd.tickCumulatives[1]"))
        );
        oracle = new OakOracle(
            address(factory), address(oak), address(poolManager), address(ethPool), SAFE, vm.addr(SIGNER_KEY)
        );
        _setSqrtPrice(uint160(_u(".oracle.spot.sqrtPriceX96")));
        vm.warp(NOW);
    }

    function test_ConstructorRejectsEveryZeroAddress() public {
        for (uint256 i; i < 6; ++i) {
            address ponsFactory = i == 0 ? address(0) : address(factory);
            address oakToken = i == 1 ? address(0) : address(oak);
            address manager = i == 2 ? address(0) : address(poolManager);
            address observations = i == 3 ? address(0) : address(ethPool);
            address safe = i == 4 ? address(0) : SAFE;
            address priceSigner = i == 5 ? address(0) : vm.addr(SIGNER_KEY);
            vm.expectRevert(OakOracle.InvalidAddress.selector);
            new OakOracle(ponsFactory, oakToken, manager, observations, safe, priceSigner);
        }
    }

    function test_ConstructorRejectsMismatchedTickSpacingOrHook() public {
        MockPonsFactory.LaunchedToken memory record = factory.getLaunchedToken(address(oak));
        record.tickSpacing = 100;
        factory.setLaunched(record);
        vm.expectRevert(
            abi.encodeWithSelector(
                OakOracle.PoolIdentityMismatch.selector, address(0), uint24(0), int24(100), PONS_HOOK
            )
        );
        new OakOracle(address(factory), address(oak), address(poolManager), address(ethPool), SAFE, vm.addr(SIGNER_KEY));

        record.tickSpacing = 200;
        factory.setLaunched(record);
        address wrongHook = address(0xBAD);
        factory.setMemeHook(wrongHook);
        vm.expectRevert(
            abi.encodeWithSelector(
                OakOracle.PoolIdentityMismatch.selector, address(0), uint24(0), int24(200), wrongHook
            )
        );
        new OakOracle(address(factory), address(oak), address(poolManager), address(ethPool), SAFE, vm.addr(SIGNER_KEY));
    }

    function test_ConstructorRejectsMissingWrongTokenNonNativePairOrPoolFee() public {
        MockPonsFactory.LaunchedToken memory record = factory.getLaunchedToken(address(oak));

        record.exists = false;
        factory.setLaunched(record);
        vm.expectRevert(
            abi.encodeWithSelector(OakOracle.LaunchRecordMismatch.selector, address(oak), address(oak), false)
        );
        new OakOracle(address(factory), address(oak), address(poolManager), address(ethPool), SAFE, vm.addr(SIGNER_KEY));

        address wrongToken = makeAddr("wrong-oracle-token");
        record.exists = true;
        record.token = wrongToken;
        factory.setLaunched(record);
        vm.expectRevert(abi.encodeWithSelector(OakOracle.LaunchRecordMismatch.selector, address(oak), wrongToken, true));
        new OakOracle(address(factory), address(oak), address(poolManager), address(ethPool), SAFE, vm.addr(SIGNER_KEY));

        address pairToken = makeAddr("non-native-pair");
        record.token = address(oak);
        record.pairToken = pairToken;
        factory.setLaunched(record);
        vm.expectRevert(
            abi.encodeWithSelector(OakOracle.PoolIdentityMismatch.selector, pairToken, uint24(0), int24(200), PONS_HOOK)
        );
        new OakOracle(address(factory), address(oak), address(poolManager), address(ethPool), SAFE, vm.addr(SIGNER_KEY));

        record.pairToken = address(0);
        record.poolFee = 1;
        factory.setLaunched(record);
        vm.expectRevert(
            abi.encodeWithSelector(
                OakOracle.PoolIdentityMismatch.selector, address(0), uint24(1), int24(200), PONS_HOOK
            )
        );
        new OakOracle(address(factory), address(oak), address(poolManager), address(ethPool), SAFE, vm.addr(SIGNER_KEY));

        record.poolFee = 0;
        factory.setLaunched(record);
        OakOracle accepted = new OakOracle(
            address(factory), address(oak), address(poolManager), address(ethPool), SAFE, vm.addr(SIGNER_KEY)
        );
        assertEq(accepted.oakToken(), address(oak));
    }

    /// @dev Phases 0, 1 and 2 replay the recorded factory return bytes; only phase 3 (never observed)
    ///      is mocked, from the recorded phase-2 record with its phase field changed.
    function test_PhaseCurveWhileFactoryPhase0Or1_ReadyAt2_Phase3Unreadable() public {
        bytes memory recordedCall = abi.encodeWithSelector(IPons.getLaunchedToken.selector, RECORDED_COIN);
        assertEq(IPons.getLaunchedToken.selector, bytes4(0x3cf28b5a));
        RecordedPonsFactory recorded = new RecordedPonsFactory();
        recorded.load(recordedCall, PHASE0_RECORD);
        OakOracle replay = new OakOracle(
            address(recorded), RECORDED_COIN, address(poolManager), address(ethPool), SAFE, vm.addr(SIGNER_KEY)
        );
        assertEq(replay.poolId(), RECORDED_POOL_ID);

        _assertRecordedPhase(recorded, replay, recordedCall, PHASE0_RECORD, 0, false);
        _assertRecordedPhase(recorded, replay, recordedCall, PHASE1_RECORD, 1, false);
        _assertRecordedPhase(recorded, replay, recordedCall, PHASE2_RECORD, 2, true);

        // Strict replay control: any other calldata is not recorded and reverts.
        (bool otherOk,) =
            address(recorded).staticcall(abi.encodeWithSelector(IPons.getLaunchedToken.selector, address(oak)));
        assertFalse(otherOk);

        // The curve address is taken from the recorded tuple's second word.
        MockCurve curveCode = new MockCurve();
        vm.etch(RECORDED_CURVE, address(curveCode).code);
        vm.store(RECORDED_CURVE, bytes32(0), bytes32(uint256(98_000_000_000_000_000)));
        recorded.load(recordedCall, PHASE0_RECORD);
        assertEq(replay.liquidityUsdgE6(), 230_632_761);

        MockPonsFactory.LaunchedToken memory rescued = abi.decode(PHASE2_RECORD, (MockPonsFactory.LaunchedToken));
        factory.setLaunched(rescued);
        OakOracle mocked = new OakOracle(
            address(factory), RECORDED_COIN, address(poolManager), address(ethPool), SAFE, vm.addr(SIGNER_KEY)
        );
        assertEq(abi.encode(factory.getLaunchedToken(RECORDED_COIN)), PHASE2_RECORD);
        assertEq(mocked.phase(), mocked.READY());
        rescued.phase = 3;
        factory.setLaunched(rescued);
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, address(factory)));
        mocked.phase();
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, address(factory)));
        mocked.available();
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, address(factory)));
        mocked.spotOakPerEthE18();
    }

    function test_EthUsdMatchesFixtureAtPinnedBlock() public view {
        assertEq(oracle.ethUsdE18(), _u(".oracle.ethUsd.ethUsdE18"));
    }

    function testFork_EthUsdMatchesFixtureAtPinnedBlock_PublicRpcPositiveControl() public {
        if (!vm.envOr("OAK_RUN_FORK_TESTS", false)) {
            vm.skip(true);
            return;
        }
        vm.createSelectFork(vm.envString("OAK_RPC_URL"), ETH_USDG_BLOCK);
        OakOracle forkOracle = new OakOracle(
            address(factory), address(oak), address(poolManager), ETH_USDG_POOL, SAFE, vm.addr(SIGNER_KEY)
        );
        assertEq(forkOracle.ethUsdE18(), _u(".oracle.ethUsd.ethUsdE18"));
    }

    function test_EthUsdUnreadable_OLD_I_Eoa_Token_FreshPool_AllNamedBehaviours() public {
        ethPool.setRevertMode(1);
        _expectUnreadable(address(ethPool));
        ethPool.setRevertMode(2);
        _expectUnreadable(address(ethPool));

        address eoa = address(0xE0A);
        assertEq(eoa.code.length, 0);
        _expectUnreadable(eoa);
        _expectUnreadable(address(new FacetNotFoundTarget()));
        _expectUnreadable(address(new EmptyReturnTarget()));

        MockObservePool fresh = new MockObservePool();
        fresh.setCumulatives(0, 0);
        assertEq(_oracleWithPool(address(fresh)).ethUsdE18(), 1e30);
    }

    function test_UnreadableFactoryRejectedAtConstruction_PoolManagerFailsClosed() public {
        address unreadableFactory = address(0xFAc7);
        vm.expectRevert(abi.encodeWithSelector(OakOracle.LaunchRecordUnreadable.selector, unreadableFactory));
        new OakOracle(
            unreadableFactory, address(oak), address(poolManager), address(ethPool), SAFE, vm.addr(SIGNER_KEY)
        );

        address unreadableManager = address(0xBADC0DE);
        OakOracle badManager = new OakOracle(
            address(factory), address(oak), unreadableManager, address(ethPool), SAFE, vm.addr(SIGNER_KEY)
        );
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, unreadableManager));
        badManager.spotOakPerEthE18();
    }

    function test_EthUsdOutOfTickRangeAndZeroResultAreUnreadable() public {
        ethPool.setCumulatives(0, int56(int256(887_273 * 1800)));
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, address(ethPool)));
        oracle.ethUsdE18();

        ethPool.setCumulatives(0, int56(int256(-887_272 * 1800)));
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, address(ethPool)));
        oracle.ethUsdE18();
    }

    function test_QuietEthUsdgPoolExtrapolatesLastTick_NoStalenessSignal() public {
        int56 tick = int56(_i(".oracle.ethUsd.meanTick"));
        ethPool.setCumulatives(0, tick * int56(uint56(1800)));
        uint256 firstReading = oracle.ethUsdE18();
        vm.warp(NOW + 7 days);
        ethPool.setCumulatives(tick * int56(uint56(7 days)), tick * int56(uint56(7 days + 1800)));
        assertEq(oracle.ethUsdE18(), firstReading);
        assertEq(firstReading, _u(".oracle.ethUsd.ethUsdE18"));
    }

    function test_SpotMatchesFixtureAtPoolOpen() public view {
        assertEq(oracle.spotOakPerEthE18(), _u(".oracle.spot.oakPerEthE18"));
        bytes32 expectedPoolId = keccak256(abi.encode(address(0), address(oak), uint24(0), int24(200), PONS_HOOK));
        assertEq(oracle.poolId(), expectedPoolId);
    }

    function test_SpotRevertsNotReadyBeforeGraduation_UnreadableAtZero() public {
        factory.setPhase(1);
        vm.expectRevert(IOakOracle.NotReady.selector);
        oracle.spotOakPerEthE18();

        factory.setPhase(2);
        _setSqrtPrice(0);
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, address(poolManager)));
        oracle.spotOakPerEthE18();
    }

    function test_ForkBuyLowersSpot() public {
        uint256 beforeSpot = oracle.spotOakPerEthE18();
        uint160 beforeSqrt = uint160(_u(".oracle.spot.sqrtPriceX96"));
        _setSqrtPrice(uint160(Math.mulDiv(beforeSqrt, 98, 100)));
        assertLt(oracle.spotOakPerEthE18(), beforeSpot);
    }

    function test_VerifyNoteAcceptsHonestNote_ReturnsItsValue() public {
        PriceNote memory note = _note(_u(".guard.lowerAccepted"), WALLET, "honest");
        bytes memory signature = _sign(note, CONSUMER, SIGNER_KEY);
        vm.prank(CONSUMER);
        assertEq(oracle.verifyNote(note, signature, WALLET), note.oakPerEthE18);
    }

    function test_VerifyNoteRejectsExpired_Future_WrongWallet_WrongConsumer_WrongChain_WrongVersion_BadSignature_ZeroSigner()
        public
    {
        uint256 value = _u(".guard.lowerAccepted");

        PriceNote memory expired = _note(value, WALLET, "expired");
        expired.timestamp = uint64(NOW - 301);
        _expectNoteRevert(expired, _sign(expired, CONSUMER, SIGNER_KEY), WALLET, IOakOracle.NoteExpired.selector);

        PriceNote memory future = _note(value, WALLET, "future");
        future.timestamp = uint64(NOW + 1);
        _expectNoteRevert(future, _sign(future, CONSUMER, SIGNER_KEY), WALLET, IOakOracle.NoteNotYetValid.selector);

        PriceNote memory wrongWallet = _note(value, WALLET, "wallet");
        _expectNoteRevert(
            wrongWallet, _sign(wrongWallet, CONSUMER, SIGNER_KEY), OTHER_WALLET, IOakOracle.NoteWrongWallet.selector
        );

        PriceNote memory wrongConsumer = _note(value, WALLET, "consumer");
        _expectNoteRevert(
            wrongConsumer,
            _sign(wrongConsumer, OTHER_CONSUMER, SIGNER_KEY),
            WALLET,
            IOakOracle.NoteBadSignature.selector
        );

        PriceNote memory wrongChain = _note(value, WALLET, "chain");
        bytes32 chainDigest = _digest(wrongChain, CONSUMER, block.chainid + 1, keccak256("1"));
        _expectNoteRevert(
            wrongChain, _signDigest(chainDigest, SIGNER_KEY), WALLET, IOakOracle.NoteBadSignature.selector
        );

        PriceNote memory wrongVersion = _note(value, WALLET, "version");
        bytes32 versionDigest = _digest(wrongVersion, CONSUMER, block.chainid, keccak256("2"));
        _expectNoteRevert(
            wrongVersion, _signDigest(versionDigest, SIGNER_KEY), WALLET, IOakOracle.NoteBadSignature.selector
        );

        PriceNote memory badSignature = _note(value, WALLET, "bad-signer");
        _expectNoteRevert(
            badSignature, _sign(badSignature, CONSUMER, BAD_SIGNER_KEY), WALLET, IOakOracle.NoteBadSignature.selector
        );

        PriceNote memory malformed = _note(value, WALLET, "malformed");
        _expectNoteRevert(malformed, hex"1234", WALLET, IOakOracle.NoteBadSignature.selector);

        vm.prank(SAFE);
        oracle.setPriceSigner(address(0));
        PriceNote memory paused = _note(value, WALLET, "zero");
        _expectNoteRevert(paused, _sign(paused, CONSUMER, SIGNER_KEY), WALLET, IOakOracle.NoteBadSignature.selector);
    }

    /// @dev OakPriceNote.recover returns address(0) for a malformed signature, which equals a zero
    ///      (paused) signer; only the explicit zero-signer check rejects these while paused.
    function test_MalformedSignatureRejected_WhileSignerSet_AndWhileSignerZero() public {
        uint256 value = _u(".guard.lowerAccepted");
        bytes[] memory malformed = _malformedSignatures();

        for (uint256 i; i < malformed.length; ++i) {
            PriceNote memory note = _note(value, WALLET, string.concat("malformed-set-", vm.toString(i)));
            _expectNoteRevert(note, malformed[i], WALLET, IOakOracle.NoteBadSignature.selector);
        }

        vm.prank(SAFE);
        oracle.setPriceSigner(address(0));
        assertEq(oracle.priceSigner(), address(0));
        for (uint256 i; i < malformed.length; ++i) {
            PriceNote memory note = _note(value, WALLET, string.concat("malformed-zero-", vm.toString(i)));
            assertEq(OakPriceNote.recover(note, malformed[i], CONSUMER), address(0));
            _expectNoteRevert(note, malformed[i], WALLET, IOakOracle.NoteBadSignature.selector);
        }
    }

    function test_NoteTtlBoundary_Accepts300SecondsOld_Rejects301_AcceptsNow_RejectsFuture() public {
        uint256 value = _u(".guard.lowerAccepted");

        PriceNote memory edge = _note(value, WALLET, "ttl-300");
        edge.timestamp = uint64(NOW - 300);
        vm.prank(CONSUMER);
        assertEq(oracle.verifyNote(edge, _sign(edge, CONSUMER, SIGNER_KEY), WALLET), value);

        PriceNote memory stale = _note(value, WALLET, "ttl-301");
        stale.timestamp = uint64(NOW - 301);
        _expectNoteRevert(stale, _sign(stale, CONSUMER, SIGNER_KEY), WALLET, IOakOracle.NoteExpired.selector);

        PriceNote memory current = _note(value, WALLET, "ttl-0");
        vm.prank(CONSUMER);
        assertEq(oracle.verifyNote(current, _sign(current, CONSUMER, SIGNER_KEY), WALLET), value);

        PriceNote memory future = _note(value, WALLET, "ttl-future");
        future.timestamp = uint64(NOW + 1);
        _expectNoteRevert(future, _sign(future, CONSUMER, SIGNER_KEY), WALLET, IOakOracle.NoteNotYetValid.selector);

        // The same note ages across the boundary: valid at +300 s, expired at +301 s.
        bytes memory signature = _sign(current, CONSUMER, SIGNER_KEY);
        vm.warp(NOW + 300);
        vm.prank(CONSUMER);
        assertEq(oracle.verifyNote(current, signature, WALLET), value);
        vm.warp(NOW + 301);
        _expectNoteRevert(current, signature, WALLET, IOakOracle.NoteExpired.selector);
    }

    function test_GuardEndpointsHalfAnd1500Accepted_OneBaseUnitOutsideRejected() public {
        _assertGuardVector(".guard", uint160(_u(".oracle.spot.sqrtPriceX96")));
        _assertGuardVector(".guard.oddSpot", 552276925551777206824881615459425);
    }

    function test_GuardTracksMovedSpot() public {
        uint160 initialSqrt = uint160(_u(".oracle.spot.sqrtPriceX96"));
        uint256 oldAverage = oracle.spotOakPerEthE18();
        PriceNote memory note = _note(oldAverage, WALLET, "moving-spot");
        bytes memory signature = _sign(note, CONSUMER, SIGNER_KEY);

        _setSqrtPrice(uint160(Math.mulDiv(initialSqrt, 8944, 10_000)));
        vm.prank(CONSUMER);
        assertEq(oracle.verifyNote(note, signature, WALLET), oldAverage);

        _setSqrtPrice(uint160(Math.mulDiv(initialSqrt, 6324, 10_000)));
        uint256 movedSpot = oracle.spotOakPerEthE18();
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.NoteOutsideGuard.selector, movedSpot, oldAverage));
        vm.prank(CONSUMER);
        oracle.verifyNote(note, signature, WALLET);
    }

    function test_SetPriceSignerOnlySafe_OldNotesRejectedFreshAccepted_ZeroPauses() public {
        PriceNote memory oldNote = _note(_u(".guard.lowerAccepted"), WALLET, "old");
        bytes memory oldSignature = _sign(oldNote, CONSUMER, SIGNER_KEY);

        vm.expectRevert(OakOracle.OnlySafe.selector);
        oracle.setPriceSigner(vm.addr(NEXT_SIGNER_KEY));

        vm.expectEmit(false, false, false, true);
        emit IOakOracle.PriceSignerSet(vm.addr(NEXT_SIGNER_KEY));
        vm.prank(SAFE);
        oracle.setPriceSigner(vm.addr(NEXT_SIGNER_KEY));

        _expectNoteRevert(oldNote, oldSignature, WALLET, IOakOracle.NoteBadSignature.selector);
        PriceNote memory fresh = _note(_u(".guard.lowerAccepted"), WALLET, "fresh");
        vm.prank(CONSUMER);
        assertEq(oracle.verifyNote(fresh, _sign(fresh, CONSUMER, NEXT_SIGNER_KEY), WALLET), fresh.oakPerEthE18);

        vm.prank(SAFE);
        oracle.setPriceSigner(address(0));
        PriceNote memory paused = _note(_u(".guard.lowerAccepted"), WALLET, "paused");
        _expectNoteRevert(
            paused, _sign(paused, CONSUMER, NEXT_SIGNER_KEY), WALLET, IOakOracle.NoteBadSignature.selector
        );
    }

    function test_LiquidityUnitsBothPhases() public {
        factory.setPhase(0);
        curve.setRealQuoteReserve(98_000_000_000_000_000);
        assertEq(oracle.liquidityUsdgE6(), 230_632_761);

        factory.setPhase(2);
        bytes32 liquiditySlot;
        unchecked {
            liquiditySlot = bytes32(uint256(oracle.spotStorageSlot()) + 3);
        }
        poolManager.setWord(liquiditySlot, bytes32(uint256(29_277_002_188_455_995_389_594)));
        assertEq(oracle.liquidityUsdgE6(), 19_768_522_432);
    }

    function test_LiquidityCurveRequiresReadableNonzeroCurve() public {
        factory.setRecord(address(oak), address(0), 0);
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, address(factory)));
        oracle.liquidityUsdgE6();

        FacetNotFoundTarget badCurve = new FacetNotFoundTarget();
        factory.setRecord(address(oak), address(badCurve), 0);
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, address(badCurve)));
        oracle.liquidityUsdgE6();
    }

    function test_SupplyNetIsTotalSupply_BurnReducesIt_DeadAddressDoesNot() public {
        assertEq(oracle.supplyNet(), 1e27);
        oak.burn(1_000e18);
        assertEq(oracle.supplyNet(), 1e27 - 1_000e18);
        oak.transfer(DEAD, 2_000e18);
        assertEq(oracle.supplyNet(), 1e27 - 1_000e18);
        assertEq(oak.balanceOf(DEAD), 2_000e18);
    }

    function test_OnlySignerIsMutable_NoOwnerNoOtherSetter() public {
        assertEq(address(uint160(uint256(vm.load(address(oracle), bytes32(0))))), vm.addr(SIGNER_KEY));
        for (uint256 i = 1; i < 8; ++i) {
            assertEq(vm.load(address(oracle), bytes32(i)), bytes32(0));
        }

        address originalFactory = oracle.ponsFactory();
        address originalToken = oracle.oakToken();
        address originalManager = oracle.poolManager();
        address originalEthPool = oracle.ethUsdgPool();
        bytes32 originalPoolId = oracle.poolId();
        (bool ownerOk,) = address(oracle).call(abi.encodeWithSignature("owner()"));
        (bool setterOk,) = address(oracle).call(abi.encodeWithSignature("setPoolManager(address)", address(1)));
        assertFalse(ownerOk);
        assertFalse(setterOk);

        vm.prank(SAFE);
        oracle.setPriceSigner(vm.addr(NEXT_SIGNER_KEY));
        assertEq(address(uint160(uint256(vm.load(address(oracle), bytes32(0))))), vm.addr(NEXT_SIGNER_KEY));
        assertEq(oracle.ponsFactory(), originalFactory);
        assertEq(oracle.oakToken(), originalToken);
        assertEq(oracle.poolManager(), originalManager);
        assertEq(oracle.ethUsdgPool(), originalEthPool);
        assertEq(oracle.poolId(), originalPoolId);
        for (uint256 i = 1; i < 8; ++i) {
            assertEq(vm.load(address(oracle), bytes32(i)), bytes32(0));
        }
    }

    function testFuzz_GuardMatchesExactInequalities(uint128 sqrtRaw, uint128 noteRaw) public {
        uint160 sqrtPriceX96 = uint160(bound(uint256(sqrtRaw), Q96 / 1000, uint256(Q96) * 1_000_000));
        _setSqrtPrice(sqrtPriceX96);
        uint256 spot = oracle.spotOakPerEthE18();
        uint256 noteValue = bound(uint256(noteRaw), 0, spot * 2);
        PriceNote memory note = _note(noteValue, WALLET, "fuzz-guard");
        bytes memory signature = _sign(note, CONSUMER, SIGNER_KEY);
        bool expected = noteValue * 2 >= spot && noteValue * 2 <= spot * 3;

        vm.prank(CONSUMER);
        (bool ok, bytes memory result) =
            address(oracle).staticcall(abi.encodeCall(IOakOracle.verifyNote, (note, signature, WALLET)));
        assertEq(ok, expected);
        if (ok) assertEq(abi.decode(result, (uint256)), noteValue);
    }

    function testFuzz_OnlySafeCanSetSigner(address caller, address nextSigner) public {
        vm.assume(caller != SAFE);
        address beforeSigner = oracle.priceSigner();
        vm.expectRevert(OakOracle.OnlySafe.selector);
        vm.prank(caller);
        oracle.setPriceSigner(nextSigner);
        assertEq(oracle.priceSigner(), beforeSigner);
    }

    function testFuzz_TickMathMonotonicAcrossValidRange(int24 rawTick) public pure {
        int24 tick = int24(bound(int256(rawTick), -887_272, 887_271));
        assertLt(OakTickMath.sqrtRatioAtTick(tick), OakTickMath.sqrtRatioAtTick(tick + 1));
    }

    function test_TickMathRejectsOutOfRange() public {
        vm.expectRevert(OakTickMath.TickOutOfBounds.selector);
        this.sqrtRatioAtTick(887_273);
    }

    function sqrtRatioAtTick(int24 tick) external pure returns (uint160) {
        return OakTickMath.sqrtRatioAtTick(tick);
    }

    function _assertGuardVector(string memory base, uint160 sqrtPriceX96) internal {
        _setSqrtPrice(sqrtPriceX96);
        uint256 spot = _u(string.concat(base, ".spotOakPerEthE18"));
        assertEq(oracle.spotOakPerEthE18(), spot);
        _assertGuardAccepted(_u(string.concat(base, ".lowerAccepted")), base);
        _assertGuardAccepted(_u(string.concat(base, ".upperAccepted")), base);
        _assertGuardRejected(_u(string.concat(base, ".lowerRejected")), base);
        _assertGuardRejected(_u(string.concat(base, ".upperRejected")), base);
    }

    function _assertGuardAccepted(uint256 value, string memory label) internal {
        PriceNote memory note = _note(value, WALLET, string.concat(label, "-accepted", vm.toString(value)));
        vm.prank(CONSUMER);
        assertEq(oracle.verifyNote(note, _sign(note, CONSUMER, SIGNER_KEY), WALLET), value);
    }

    function _assertGuardRejected(uint256 value, string memory label) internal {
        PriceNote memory note = _note(value, WALLET, string.concat(label, "-rejected", vm.toString(value)));
        uint256 spot = oracle.spotOakPerEthE18();
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.NoteOutsideGuard.selector, spot, value));
        vm.prank(CONSUMER);
        oracle.verifyNote(note, _sign(note, CONSUMER, SIGNER_KEY), WALLET);
    }

    function _assertRecordedPhase(
        RecordedPonsFactory recorded,
        OakOracle replay,
        bytes memory recordedCall,
        bytes memory record,
        uint8 expectedPhase,
        bool ready
    ) internal {
        MockPonsFactory.LaunchedToken memory decoded = abi.decode(record, (MockPonsFactory.LaunchedToken));
        assertEq(abi.encode(decoded), record);
        assertEq(decoded.token, RECORDED_COIN);
        assertEq(decoded.curve, RECORDED_CURVE);
        assertEq(decoded.deployer, RECORDED_DEPLOYER);
        assertEq(decoded.creatorFeeRecipient, RECORDED_DEPLOYER);
        assertEq(decoded.pairToken, address(0));
        assertEq(decoded.graduationThreshold, 4_200_000_000_000_000_000);
        assertEq(decoded.poolFee, 0);
        assertEq(decoded.tickSpacing, 200);
        assertEq(decoded.creatorTaxBps, 200);
        assertFalse(decoded.buybackEnabled);
        assertEq(decoded.phase, expectedPhase);
        assertTrue(decoded.exists);

        recorded.load(recordedCall, record);
        assertEq(replay.phase(), ready ? replay.READY() : replay.CURVE());
        assertEq(replay.available(), ready);
    }

    function _malformedSignatures() internal pure returns (bytes[] memory signatures) {
        signatures = new bytes[](5);
        signatures[0] = hex"1234";
        signatures[1] = new bytes(65);
        signatures[2] = "";
        signatures[3] = abi.encodePacked(bytes32(uint256(1)), bytes32(uint256(1)), uint8(29));
        signatures[4] = abi.encodePacked(bytes32(uint256(1)), bytes32(type(uint256).max), uint8(27));
    }

    function _expectUnreadable(address source) internal {
        OakOracle candidate = _oracleWithPool(source);
        vm.expectRevert(abi.encodeWithSelector(IOakOracle.OracleUnreadable.selector, source));
        candidate.ethUsdE18();
    }

    function _oracleWithPool(address source) internal returns (OakOracle) {
        return new OakOracle(address(factory), address(oak), address(poolManager), source, SAFE, vm.addr(SIGNER_KEY));
    }

    function _expectNoteRevert(PriceNote memory note, bytes memory signature, address boundWallet, bytes4 selector)
        internal
    {
        vm.expectRevert(selector);
        vm.prank(CONSUMER);
        oracle.verifyNote(note, signature, boundWallet);
    }

    function _setSqrtPrice(uint160 sqrtPriceX96) internal {
        poolManager.setWord(oracle.spotStorageSlot(), bytes32(uint256(sqrtPriceX96)));
    }

    function _note(uint256 value, address wallet, string memory salt) internal pure returns (PriceNote memory) {
        return PriceNote(wallet, value, uint64(NOW), keccak256(bytes(salt)));
    }

    function _sign(PriceNote memory note, address consumer, uint256 key) internal view returns (bytes memory) {
        return _signDigest(OakPriceNote.digest(note, consumer), key);
    }

    function _signDigest(bytes32 digest_, uint256 key) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest_);
        return abi.encodePacked(r, s, v);
    }

    function _digest(PriceNote memory note, address consumer, uint256 chainId, bytes32 versionHash)
        internal
        pure
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("PriceNote(address wallet,uint256 oakPerEthE18,uint64 timestamp,bytes32 nonce)"),
                note.wallet,
                note.oakPerEthE18,
                note.timestamp,
                note.nonce
            )
        );
        bytes32 domain = keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, versionHash, chainId, consumer));
        return MessageHashUtils.toTypedDataHash(domain, structHash);
    }

    function _u(string memory path) internal view returns (uint256) {
        return vm.parseUint(vectors.readString(path));
    }

    function _i(string memory path) internal view returns (int256) {
        return vm.parseInt(vectors.readString(path));
    }
}

contract DeployOracleTest is Test {
    address internal constant TOKEN = address(0x0A4);
    address internal constant SAFE = address(0x5AFE);
    address internal constant SIGNER = address(0x516);

    DeployOracle internal script;

    function setUp() public {
        script = new DeployOracle();
        vm.etch(TOKEN, hex"00");
        _mockIdentity(script.MAINNET_PONS_FACTORY(), TOKEN, 0, 200, script.PONS_HOOK(), true);
    }

    function test_DeployScript_MainnetPinsAccepted_DeploysExactImmutables() public {
        vm.chainId(4663);
        _assertDeployed(script.deploy(_mainnetConfig()), _mainnetConfig());
    }

    function test_DeployScriptRejectsMismatchedTickSpacingOrHook() public {
        vm.chainId(4663);
        DeployOracle.Config memory config = _mainnetConfig();

        vm.clearMockedCalls();
        _mockIdentity(config.ponsFactory, TOKEN, 0, 100, script.PONS_HOOK(), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployOracle.PoolIdentityMismatch.selector, address(0), uint24(0), int24(100), script.PONS_HOOK()
            )
        );
        script.deploy(config);

        address wrongHook = address(0xBAD);
        vm.clearMockedCalls();
        _mockIdentity(config.ponsFactory, TOKEN, 0, 200, wrongHook, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployOracle.PoolIdentityMismatch.selector, address(0), uint24(0), int24(200), wrongHook
            )
        );
        script.deploy(config);
    }

    function test_DeployScript_ExplicitConfigDeploys() public {
        DeployOracle.Config memory config = _mainnetConfig();
        vm.chainId(4663);
        _assertDeployed(script.deploy(config), config);
    }

    function test_DeployScript_RefusesEveryOtherChain() public {
        DeployOracle.Config memory config = _mainnetConfig();
        uint256[6] memory chains = [uint256(1), 31_337, 4662, 4664, 46_629, 46_631];
        for (uint256 i; i < chains.length; ++i) {
            vm.chainId(chains[i]);
            vm.expectRevert(abi.encodeWithSelector(DeployOracle.UnsupportedChain.selector, chains[i]));
            script.deploy(config);
        }
    }

    function test_DeployScript_MainnetRefusesEachUnpinnedSource() public {
        vm.chainId(4663);
        address impostor = address(new DeployOracle());
        assertGt(impostor.code.length, 0);

        DeployOracle.Config memory config = _mainnetConfig();
        config.ponsFactory = impostor;
        _expectUnpinned(config, "OAK_PONS_FACTORY_ADDRESS", script.MAINNET_PONS_FACTORY(), impostor);

        config = _mainnetConfig();
        config.poolManager = impostor;
        _expectUnpinned(config, "OAK_POOL_MANAGER_ADDRESS", script.MAINNET_POOL_MANAGER(), impostor);

        config = _mainnetConfig();
        config.ethUsdgPool = impostor;
        _expectUnpinned(config, "OAK_ETH_USDG_POOL_ADDRESS", script.MAINNET_ETH_USDG_POOL(), impostor);

        config = _mainnetConfig();
        (config.ponsFactory, config.poolManager) = (config.poolManager, config.ponsFactory);
        _expectUnpinned(config, "OAK_PONS_FACTORY_ADDRESS", script.MAINNET_PONS_FACTORY(), config.ponsFactory);
    }

    function test_DeployScript_RefusesEachZeroAddress() public {
        vm.chainId(4663);
        for (uint256 i; i < 6; ++i) {
            DeployOracle.Config memory config = _mainnetConfig();
            string memory variableName;
            if (i == 0) (config.ponsFactory, variableName) = (address(0), "OAK_PONS_FACTORY_ADDRESS");
            if (i == 1) (config.oakToken, variableName) = (address(0), "OAK_TOKEN_ADDRESS");
            if (i == 2) (config.poolManager, variableName) = (address(0), "OAK_POOL_MANAGER_ADDRESS");
            if (i == 3) (config.ethUsdgPool, variableName) = (address(0), "OAK_ETH_USDG_POOL_ADDRESS");
            if (i == 4) (config.safe, variableName) = (address(0), "OAK_SAFE_ADDRESS");
            if (i == 5) (config.priceSigner, variableName) = (address(0), "OAK_PRICE_SIGNER_ADDRESS");
            vm.expectRevert(abi.encodeWithSelector(DeployOracle.ZeroDeploymentAddress.selector, variableName));
            script.deploy(config);
        }
    }

    function test_DeployScript_TestnetPinsPoolManager_RequiresCodeForUnpinnedSources() public {
        vm.chainId(46_630);
        address testFactory = address(0xFAC7);
        address testPool = address(0x9001);
        DeployOracle.Config memory config = DeployOracle.Config({
            ponsFactory: testFactory,
            oakToken: TOKEN,
            poolManager: script.TESTNET_POOL_MANAGER(),
            ethUsdgPool: testPool,
            safe: SAFE,
            priceSigner: SIGNER
        });

        vm.expectRevert(
            abi.encodeWithSelector(DeployOracle.MissingCode.selector, "OAK_PONS_FACTORY_ADDRESS", testFactory)
        );
        script.deploy(config);
        vm.etch(testFactory, hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(DeployOracle.MissingCode.selector, "OAK_ETH_USDG_POOL_ADDRESS", testPool)
        );
        script.deploy(config);
        vm.etch(testPool, hex"00");
        _mockIdentity(testFactory, TOKEN, 0, 200, script.PONS_HOOK(), true);
        _assertDeployed(script.deploy(config), config);

        // The mainnet Pons factory has no code on 46630, so the production pins are refused there.
        vm.clearMockedCalls();
        vm.etch(script.MAINNET_PONS_FACTORY(), bytes(""));
        DeployOracle.Config memory production = _mainnetConfig();
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployOracle.MissingCode.selector, "OAK_PONS_FACTORY_ADDRESS", script.MAINNET_PONS_FACTORY()
            )
        );
        script.deploy(production);

        config.poolManager = address(0xBEEF);
        _expectUnpinned(config, "OAK_POOL_MANAGER_ADDRESS", script.TESTNET_POOL_MANAGER(), address(0xBEEF));
    }

    function _mainnetConfig() internal view returns (DeployOracle.Config memory) {
        return DeployOracle.Config({
            ponsFactory: script.MAINNET_PONS_FACTORY(),
            oakToken: TOKEN,
            poolManager: script.MAINNET_POOL_MANAGER(),
            ethUsdgPool: script.MAINNET_ETH_USDG_POOL(),
            safe: SAFE,
            priceSigner: SIGNER
        });
    }

    function _expectUnpinned(
        DeployOracle.Config memory config,
        string memory variableName,
        address expected,
        address actual
    ) internal {
        vm.expectRevert(abi.encodeWithSelector(DeployOracle.UnpinnedAddress.selector, variableName, expected, actual));
        script.deploy(config);
    }

    function _assertDeployed(OakOracle deployed, DeployOracle.Config memory config) internal view {
        assertEq(deployed.ponsFactory(), config.ponsFactory);
        assertEq(deployed.oakToken(), config.oakToken);
        assertEq(deployed.poolManager(), config.poolManager);
        assertEq(deployed.ethUsdgPool(), config.ethUsdgPool);
        assertEq(deployed.safe(), config.safe);
        assertEq(deployed.priceSigner(), config.priceSigner);
    }

    function _mockIdentity(address factory, address token, uint24 poolFee, int24 tickSpacing, address hook, bool exists)
        internal
    {
        PonsLaunchRecord memory record;
        record.token = token;
        record.poolFee = poolFee;
        record.tickSpacing = tickSpacing;
        record.exists = exists;
        vm.mockCall(factory, abi.encodeCall(IPonsFactoryView.getLaunchedToken, (token)), abi.encode(record));
        vm.mockCall(factory, abi.encodeCall(IPonsFactoryView.memeHook, ()), abi.encode(hook));
    }
}
