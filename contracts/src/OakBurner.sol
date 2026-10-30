// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IOakBurner} from "./interfaces/IOakBurner.sol";
import {IOakOracle} from "./interfaces/IOakOracle.sol";
import {PriceNote} from "./libraries/OakPriceNote.sol";
import {OakPricing} from "./libraries/OakPricing.sol";

interface IBurnableERC20 is IERC20 {
    function burn(uint256 amount) external;
}

interface IWETH9 is IERC20 {
    function withdraw(uint256 amount) external;
}

interface IV3SwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
}

interface ISwapRouter02 is IV3SwapRouter {
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

/// @dev Universal Router v2.1.2 / Pons six-field exact-input shape. The fifth
///      field is deliberately retained even when zero; omitting it selects the
///      incompatible legacy five-field encoding.
struct V4ExactInputSingleParams {
    PoolKey poolKey;
    bool zeroForOne;
    uint128 amountIn;
    uint128 amountOutMinimum;
    uint256 minHopPriceX36;
    bytes hookData;
}

/// @notice Converts accumulated USDG into native ETH and then OAK, and truly burns the OAK.
/// @dev Route contracts and pool shape are fixed to the chain-4663 deployment pins.
contract OakBurner is IOakBurner, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
    address public constant SWAP_ROUTER_02 = 0xCaf681a66D020601342297493863E78C959E5cb2;
    address public constant UNIVERSAL_ROUTER_V2_1_2 = 0x204FAca1764B154221e35c0d20aBb3c525710498;
    address public constant PONS_HOOK = 0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044;

    uint24 public constant V3_FEE = 100;
    uint24 public constant V4_FEE = 0;
    int24 public constant V4_TICK_SPACING = 200;
    uint256 public constant SWEEP_DELAY = 90 days;

    bytes1 private constant V4_SWAP_COMMAND = 0x10;
    bytes private constant V4_BUY_ACTIONS = hex"060c0f";
    uint256 private constant CHUNK_DENOMINATOR = 200;

    IERC20 public immutable usdg;
    IBurnableERC20 public immutable oak;
    IOakOracle public immutable oracle;
    address public immutable safe;
    uint8 public immutable override oakDecimals;

    mapping(address wallet => mapping(bytes32 nonce => bool used)) public override noteUsed;
    uint64 public override armedAt;
    uint256 public override armedBalance;
    uint64 public override lastBurnAt;

    error InvalidAddress();
    error InvalidOakDecimals(uint8 decimals);
    error OnlySafe();
    error ZeroAmount();
    error ChunkTooLarge(uint256 requested, uint256 maximum);
    error RouterAmountOverflow();
    error ZeroSwapOutput();
    error TooLittleOak(uint256 minimum, uint256 actual);
    error UnexpectedNativeSender();
    error NoBalance();
    error AlreadyArmed();
    error NotArmed();
    error SweepNotReady(uint256 readyAt);

    constructor(address usdg_, address oak_, address oracle_, address safe_, uint8 oakDecimals_) {
        if (usdg_ == address(0) || oak_ == address(0) || oracle_ == address(0) || safe_ == address(0)) {
            revert InvalidAddress();
        }
        if (oakDecimals_ < 6 || oakDecimals_ > 77) revert InvalidOakDecimals(oakDecimals_);
        usdg = IERC20(usdg_);
        oak = IBurnableERC20(oak_);
        oracle = IOakOracle(oracle_);
        safe = safe_;
        oakDecimals = oakDecimals_;
    }

    receive() external payable {
        if (msg.sender != WETH) revert UnexpectedNativeSender();
    }

    /// @inheritdoc IOakBurner
    function buyAndBurn(uint256 usdgIn, PriceNote calldata n, bytes calldata sig) external nonReentrant {
        if (usdgIn == 0) revert ZeroAmount();

        oracle.syncPhase();
        uint256 maximum = oracle.liquidityUsdgE6() / CHUNK_DENOMINATOR;
        if (usdgIn > maximum) revert ChunkTooLarge(usdgIn, maximum);

        uint256 oakPerEthE18 = oracle.verifyNote(n, sig, msg.sender);
        if (noteUsed[msg.sender][n.nonce]) revert NoteUsed();
        noteUsed[msg.sender][n.nonce] = true;

        uint256 ethUsdE18 = oracle.ethUsdE18();
        uint256 minOakOut = OakPricing.burnerMinOut(usdgIn, oakPerEthE18, ethUsdE18, oakDecimals);
        uint256 ethOut = _swapUsdgForWeth(usdgIn);
        if (ethOut == 0) revert ZeroSwapOutput();
        if (ethOut > type(uint128).max || minOakOut > type(uint128).max) revert RouterAmountOverflow();

        IWETH9(WETH).withdraw(ethOut);

        uint256 oakBefore = oak.balanceOf(address(this));
        _swapNativeForOak(uint128(ethOut), uint128(minOakOut));
        uint256 oakOut = oak.balanceOf(address(this)) - oakBefore;
        if (oakOut < minOakOut) revert TooLittleOak(minOakOut, oakOut);
        oak.burn(oakOut);

        lastBurnAt = uint64(block.timestamp);
        if (armedAt != 0) {
            armedAt = 0;
            armedBalance = 0;
            emit SweepDisarmed(0);
        }
        emit Burned(usdgIn, oakOut);
    }

    /// @inheritdoc IOakBurner
    function armSweep() external nonReentrant onlySafe {
        if (armedAt != 0) revert AlreadyArmed();
        uint256 balance = usdg.balanceOf(address(this));
        if (balance == 0) revert NoBalance();
        armedAt = uint64(block.timestamp);
        armedBalance = balance;
        emit SweepArmed(armedAt, balance);
    }

    /// @inheritdoc IOakBurner
    function sweepStuck() external nonReentrant onlySafe {
        uint64 armedAt_ = armedAt;
        if (armedAt_ == 0) revert NotArmed();
        uint256 readyAt = uint256(armedAt_) + SWEEP_DELAY;
        if (block.timestamp < readyAt) revert SweepNotReady(readyAt);

        uint256 balance = usdg.balanceOf(address(this));
        uint256 amount = balance < armedBalance ? balance : armedBalance;
        armedAt = 0;
        armedBalance = 0;
        emit SweepDisarmed(1);
        usdg.safeTransfer(safe, amount);
        emit Swept(amount);
    }

    modifier onlySafe() {
        if (msg.sender != safe) revert OnlySafe();
        _;
    }

    function _swapUsdgForWeth(uint256 amountIn) private returns (uint256 amountOut) {
        usdg.forceApprove(SWAP_ROUTER_02, amountIn);
        amountOut = ISwapRouter02(SWAP_ROUTER_02)
            .exactInputSingle(
                IV3SwapRouter.ExactInputSingleParams({
                    tokenIn: address(usdg),
                    tokenOut: WETH,
                    fee: V3_FEE,
                    recipient: address(this),
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );
        usdg.forceApprove(SWAP_ROUTER_02, 0);
    }

    function _swapNativeForOak(uint128 amountIn, uint128 minOakOut) private {
        PoolKey memory key = PoolKey({
            currency0: address(0), currency1: address(oak), fee: V4_FEE, tickSpacing: V4_TICK_SPACING, hooks: PONS_HOOK
        });
        V4ExactInputSingleParams memory swap = V4ExactInputSingleParams({
            poolKey: key,
            zeroForOne: true,
            amountIn: amountIn,
            amountOutMinimum: minOakOut,
            minHopPriceX36: 0,
            hookData: bytes("")
        });

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(swap);
        params[1] = abi.encode(address(0), uint256(amountIn));
        params[2] = abi.encode(address(oak), uint256(minOakOut));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(V4_BUY_ACTIONS, params);
        IUniversalRouter(UNIVERSAL_ROUTER_V2_1_2).execute{value: amountIn}(
            abi.encodePacked(V4_SWAP_COMMAND), inputs, block.timestamp
        );
    }
}
