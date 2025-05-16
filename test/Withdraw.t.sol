// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {YieldzAVS} from "../src/YieldzAVS.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract VaultWithdrawTest is Test {
    Vault public vault;
    YieldzAVS public yieldzAVS;
    MockUSDC public mockUSDC;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    uint256 constant INITIAL_BALANCE = 10_000_000;
    uint256 constant DEPOSIT_AMOUNT = 1_000_000;
    uint256 constant WITHDRAW_AMOUNT = 500_000;

    function setUp() public {
        // Deploy contracts
        mockUSDC = new MockUSDC();
        yieldzAVS = new YieldzAVS();
        vault = new Vault(address(mockUSDC), address(yieldzAVS));

        // Setup test accounts with tokens
        mockUSDC.mint(user1, INITIAL_BALANCE);
        mockUSDC.mint(user2, INITIAL_BALANCE);

        // Approve vault to spend tokens
        vm.startPrank(user1);
        mockUSDC.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        mockUSDC.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        // User1 deposits to have shares for withdrawal tests
        vm.startPrank(user1);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function test_WithdrawReturnsCorrectTokens() public {
        uint256 initialBalance = mockUSDC.balanceOf(user1);
        uint256 initialShares = vault.balanceOf(user1);
        uint256 halfShares = initialShares / 2;

        vm.startPrank(user1);
        vault.withdraw(halfShares);
        vm.stopPrank();

        // Check user received correct amount of tokens
        uint256 expectedTokens = DEPOSIT_AMOUNT / 2; // Since we're withdrawing half the shares
        uint256 newBalance = mockUSDC.balanceOf(user1);
        assertEq(newBalance - initialBalance, expectedTokens);

        // Check user's shares were reduced correctly
        assertEq(vault.balanceOf(user1), initialShares - halfShares);
    }

    function test_WithdrawUpdatesState() public {
        uint256 initialTotalAssets = vault.totalAssets();
        uint256 initialTotalSupply = vault.totalSupply();
        uint256 halfShares = vault.balanceOf(user1) / 2;

        vm.startPrank(user1);
        vault.withdraw(halfShares);
        vm.stopPrank();

        // Check vault state updates
        assertEq(vault.totalAssets(), initialTotalAssets - (DEPOSIT_AMOUNT / 2));
        assertEq(vault.totalSupply(), initialTotalSupply - halfShares);
    }

    function test_WithdrawEmitsEvent() public {
        uint256 halfShares = vault.balanceOf(user1) / 2;
        uint256 expectedTokens = DEPOSIT_AMOUNT / 2;

        vm.startPrank(user1);

        vm.expectEmit(true, true, true, true);
        emit Vault.Withdraw(
            user1, halfShares, expectedTokens, DEPOSIT_AMOUNT - expectedTokens, DEPOSIT_AMOUNT - halfShares
        );

        vault.withdraw(halfShares);
        vm.stopPrank();
    }

    function test_WithdrawFullAmount() public {
        uint256 initialBalance = mockUSDC.balanceOf(user1);
        uint256 fullShares = vault.balanceOf(user1);

        vm.startPrank(user1);
        vault.withdraw(fullShares);
        vm.stopPrank();

        // Check user received all tokens
        assertEq(mockUSDC.balanceOf(user1) - initialBalance, DEPOSIT_AMOUNT);

        // Check user has no shares left
        assertEq(vault.balanceOf(user1), 0);

        // Check vault state
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);
    }

    function test_WithdrawAfterYield() public {
        // Distribute yield
        mockUSDC.mint(address(this), DEPOSIT_AMOUNT);
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        vault.distributeYield(DEPOSIT_AMOUNT);

        // Now totalAssets = 2 * DEPOSIT_AMOUNT but shares remain the same
        uint256 initialBalance = mockUSDC.balanceOf(user1);
        uint256 fullShares = vault.balanceOf(user1);

        vm.startPrank(user1);
        vault.withdraw(fullShares);
        vm.stopPrank();

        // User should receive 2x their initial deposit due to yield
        assertEq(mockUSDC.balanceOf(user1) - initialBalance, 2 * DEPOSIT_AMOUNT);
    }

    function test_WithdrawWithMultipleUsers() public {
        // User2 also deposits
        vm.startPrank(user2);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        // User1 withdraws half
        uint256 user1Shares = vault.balanceOf(user1);
        uint256 halfShares = user1Shares / 2;

        vm.startPrank(user1);
        vault.withdraw(halfShares);
        vm.stopPrank();

        // Check user1 state
        assertEq(vault.balanceOf(user1), user1Shares - halfShares);

        // Check vault state - adjusted for correct calculation
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT * 3 / 2);
        assertEq(vault.totalSupply(), DEPOSIT_AMOUNT * 3 / 2);
    }

    function test_ZeroSharesWithdrawReverts() public {
        vm.startPrank(user1);
        vm.expectRevert(Vault.NothingToShares.selector);
        vault.withdraw(0);
        vm.stopPrank();
    }

    function test_ExcessSharesWithdrawReverts() public {
        uint256 userShares = vault.balanceOf(user1);

        vm.startPrank(user1);
        vm.expectRevert(Vault.NotEnoughShares.selector);
        vault.withdraw(userShares + 1);
        vm.stopPrank();
    }

    function test_WithdrawByNonOwnerReverts() public {
        uint256 user1Shares = vault.balanceOf(user1);

        vm.startPrank(user2);
        vm.expectRevert(Vault.NotEnoughShares.selector);
        vault.withdraw(user1Shares);
        vm.stopPrank();
    }
}
