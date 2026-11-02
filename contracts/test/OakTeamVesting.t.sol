// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VestingWalletCliff} from "@openzeppelin/contracts/finance/VestingWalletCliff.sol";
import {OakTeamVesting} from "../src/OakTeamVesting.sol";

contract VestingTestToken is ERC20 {
    constructor() ERC20("Test OAK", "OAK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract OakTeamVestingTest is Test {
    OakTeamVesting internal vesting;
    VestingTestToken internal token;
    address internal beneficiary = address(0xBEEF);
    address internal stranger = address(0xBAD);
    uint64 internal constant START = 2_000_000_000;
    uint64 internal constant DURATION = 1000;
    uint64 internal constant CLIFF = 200;
    uint256 internal constant ALLOCATION = 100_000 ether;

    function setUp() public {
        vesting = new OakTeamVesting(beneficiary, START, DURATION, CLIFF);
        token = new VestingTestToken();
        token.transfer(address(vesting), ALLOCATION);
    }

    function test_Getters() public view {
        assertEq(vesting.owner(), beneficiary);
        assertEq(vesting.start(), START);
        assertEq(vesting.duration(), DURATION);
        assertEq(vesting.cliff(), START + CLIFF);
        assertEq(vesting.end(), START + DURATION);
    }

    function test_CliffLinearAndEnd() public {
        vm.warp(START + CLIFF - 1);
        assertEq(vesting.releasable(address(token)), 0);
        vesting.release(address(token));
        assertEq(token.balanceOf(beneficiary), 0);
        vm.warp(START + CLIFF);
        assertEq(vesting.releasable(address(token)), ALLOCATION / 5);
        vesting.release(address(token));
        vm.warp(START + DURATION / 2);
        assertEq(vesting.releasable(address(token)), ALLOCATION / 2 - ALLOCATION / 5);
        vesting.release(address(token));
        assertEq(token.balanceOf(beneficiary), ALLOCATION / 2);
        vm.warp(START + DURATION);
        vesting.release(address(token));
        assertEq(token.balanceOf(beneficiary), ALLOCATION);
        assertEq(token.balanceOf(address(vesting)), 0);
        assertEq(vesting.released(address(token)), ALLOCATION);
        vesting.release(address(token));
        assertEq(token.balanceOf(beneficiary), ALLOCATION);
    }

    function test_AnyoneCanReleaseOnlyToBeneficiary() public {
        vm.warp(START + DURATION / 2);
        vm.prank(stranger);
        vesting.release(address(token));
        assertEq(token.balanceOf(stranger), 0);
        assertEq(token.balanceOf(beneficiary), ALLOCATION / 2);
    }

    function test_NoDeployerOrBeneficiaryEarlyWithdrawal() public {
        vm.warp(START + CLIFF - 1);
        // Positive control: this token supports transfer; deployer already funded the vesting wallet.
        assertEq(token.balanceOf(address(vesting)), ALLOCATION);
        for (uint256 i; i < 2; ++i) {
            address caller = i == 0 ? address(this) : beneficiary;
            vm.startPrank(caller);
            vesting.release(address(token));
            (bool ok,) =
                address(vesting).call(abi.encodeWithSignature("withdraw(address,uint256)", address(token), ALLOCATION));
            assertFalse(ok);
            (ok,) = address(vesting).call(abi.encodeWithSignature("emergencyWithdraw(address)", address(token)));
            assertFalse(ok);
            (ok,) = address(vesting).call(abi.encodeWithSignature("sweep(address)", address(token)));
            assertFalse(ok);
            vm.stopPrank();
        }
        assertEq(token.balanceOf(address(vesting)), ALLOCATION);
        assertEq(token.balanceOf(beneficiary), 0);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vesting.transferOwnership(stranger);
    }

    function test_BeneficiaryTransferChangesRecipientWithoutAccelerating() public {
        vm.prank(beneficiary);
        vesting.transferOwnership(stranger);
        vm.warp(START + CLIFF - 1);
        assertEq(vesting.releasable(address(token)), 0);
        vm.warp(START + DURATION);
        vesting.release(address(token));
        assertEq(token.balanceOf(stranger), ALLOCATION);
        assertEq(token.balanceOf(beneficiary), 0);
    }

    function test_LateDepositUsesOriginalSchedule() public {
        vm.warp(START + DURATION / 2);
        vesting.release(address(token));
        token.transfer(address(vesting), ALLOCATION);
        assertEq(vesting.releasable(address(token)), ALLOCATION / 2);
    }

    function test_NativeCurrencySameSchedule() public {
        vm.deal(address(vesting), 10 ether);
        vm.warp(START + CLIFF - 1);
        assertEq(vesting.releasable(), 0);
        vm.warp(START + DURATION);
        vm.prank(stranger);
        vesting.release();
        assertEq(beneficiary.balance, 10 ether);
        assertEq(stranger.balance, 0);
    }

    function test_InvalidConstructors() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new OakTeamVesting(address(0), START, DURATION, CLIFF);
        vm.expectRevert(
            abi.encodeWithSelector(VestingWalletCliff.InvalidCliffDuration.selector, DURATION + 1, DURATION)
        );
        new OakTeamVesting(beneficiary, START, DURATION, DURATION + 1);
    }

    function test_ZeroCliffAndCliffAtEnd() public {
        OakTeamVesting linear = new OakTeamVesting(beneficiary, START, DURATION, 0);
        OakTeamVesting locked = new OakTeamVesting(beneficiary, START, DURATION, DURATION);
        token.transfer(address(linear), ALLOCATION);
        token.transfer(address(locked), ALLOCATION);
        vm.warp(START + DURATION / 2);
        assertEq(linear.releasable(address(token)), ALLOCATION / 2);
        assertEq(locked.releasable(address(token)), 0);
        vm.warp(START + DURATION);
        assertEq(locked.releasable(address(token)), ALLOCATION);
    }

    function testFuzz_ConservationMonotonicAndNoEarlyRelease(uint64 first, uint64 second) public {
        first = uint64(bound(first, START - 100, START + DURATION + 100));
        second = uint64(bound(second, first, START + DURATION + 100));
        vm.warp(first);
        uint256 expected = first < START + CLIFF
            ? 0
            : first >= START + DURATION ? ALLOCATION : ALLOCATION * (first - START) / DURATION;
        assertEq(vesting.releasable(address(token)), expected);
        vm.prank(stranger);
        vesting.release(address(token));
        vm.warp(second);
        assertGe(vesting.vestedAmount(address(token), second), expected);
        vesting.release(address(token));
        assertEq(token.balanceOf(address(vesting)) + token.balanceOf(beneficiary), ALLOCATION);
        assertEq(token.balanceOf(beneficiary), vesting.released(address(token)));
        assertEq(token.balanceOf(stranger), 0);
        assertLe(vesting.released(address(token)), ALLOCATION);
        assertEq(vesting.releasable(address(token)), 0);
    }
}
