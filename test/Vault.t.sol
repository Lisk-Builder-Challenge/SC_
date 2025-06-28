// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {YieldzAVS} from "../src/YieldzAVS.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }
}

contract TestVault is Test {
    Vault vault;
    YieldzAVS avs;
    MockToken token;
    address user = address(0x1);
    address operator = address(0x2);
    address unauthorized = address(0x3);

    function setUp() public {
        token = new MockToken();
        avs = new YieldzAVS();
        vault = new Vault(address(token), address(avs));

        // Transfer tokens to user and operator
        token.transfer(user, 10_000 * 10 ** 18);
        token.transfer(operator, 10_000 * 10 ** 18);

        // Approve Vault to spend user's tokens
        vm.startPrank(user);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        // Approve AVS to spend operator's tokens
        vm.startPrank(operator);
        token.approve(address(avs), type(uint256).max);
        vm.stopPrank();
    }

    // Test deposit functionality
    function testDeposit() public {
        vm.startPrank(user);
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 shares = vault.deposit(depositAmount);

        assertEq(vault.totalAssets(), depositAmount, "Total assets should match deposit");
        assertEq(vault.totalSupply(), shares, "Total shares should match minted shares");
        assertEq(vault.balanceOf(user), shares, "User should receive shares");
        assertEq(token.balanceOf(address(vault)), depositAmount, "Vault should hold tokens");
        assertEq(shares, depositAmount, "Shares should equal deposit amount (1:1 initially)");
        vm.stopPrank();
    }

    // Test deposit with zero amount should fail
    function testFailDepositZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(Vault.ZeroAmount.selector);
        vault.deposit(0);
        vm.stopPrank();
    }

    // Test withdraw functionality
    function testWithdraw() public {
        vm.startPrank(user);
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 shares = vault.deposit(depositAmount);
        vault.withdraw(shares);

        assertEq(vault.totalAssets(), 0, "Total assets should be zero after withdraw");
        assertEq(vault.totalSupply(), 0, "Total shares should be zero after withdraw");
        assertEq(vault.balanceOf(user), 0, "User should have no shares");
        assertEq(token.balanceOf(address(vault)), 0, "Vault should have no tokens");
        assertEq(token.balanceOf(user), 10_000 * 10 ** 18, "User should get tokens back");
        vm.stopPrank();
    }

    // Test withdraw with insufficient shares should fail
    function testFailWithdrawInsufficientShares() public {
        vm.startPrank(user);
        vault.deposit(1000 * 10 ** 18);
        vm.expectRevert(Vault.NotEnoughShares.selector);
        vault.withdraw(2000 * 10 ** 18);
        vm.stopPrank();
    }

    // Test addAssets by AVS
    function testAddAssets() public {
        vm.startPrank(operator);
        uint256 yieldAmount = 500 * 10 ** 18;
        avs.distributeYield(address(vault), yieldAmount);

        assertEq(vault.totalAssets(), yieldAmount, "Total assets should increase by yield");
        assertEq(token.balanceOf(address(vault)), yieldAmount, "Vault should hold yield tokens");
        vm.stopPrank();
    }

    // Test addAssets by unauthorized address should fail
    function testFailAddAssetsUnauthorized() public {
        vm.startPrank(unauthorized);
        vm.expectRevert(Vault.Unauthorized.selector);
        vault.addAssets(500 * 10 ** 18);
        vm.stopPrank();
    }

    // Test removeAssets by AVS
    function testRemoveAssets() public {
        vm.startPrank(user);
        vault.deposit(1000 * 10 ** 18); // Provide liquidity
        vm.stopPrank();

        vm.startPrank(operator);
        uint256 borrowAmount = 500 * 10 ** 18;
        avs.borrowFund(address(vault), operator, borrowAmount,  100, block.timestamp + 365 days);

        assertEq(vault.totalAssets(), 500 * 10 ** 18, "Total assets should decrease by borrow amount");
        assertEq(vault.totalBorrowed(), borrowAmount, "Total borrowed should increase");
        assertEq(token.balanceOf(operator), 10_000 * 10 ** 18 + borrowAmount, "Operator should receive tokens");
        vm.stopPrank();
    }

    // Test removeAssets with insufficient liquidity should fail
    function testFailRemoveAssetsInsufficientLiquidity() public {
        vm.startPrank(operator);
        vm.expectRevert(Vault.InsufficientLiquidity.selector);
        avs.borrowFund(address(vault), operator, 1000 * 10 ** 18, 100, block.timestamp + 365 days);
        vm.stopPrank();
    }

    // Test reduceBorrowed by AVS
    function testReduceBorrowed() public {
        vm.startPrank(user);
        vault.deposit(1000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(operator);
        uint256 borrowAmount = 500 * 10 ** 18;
        avs.borrowFund(address(vault), operator, borrowAmount, 100, block.timestamp + 365 days);
        avs.repayByAVS(address(vault), operator, borrowAmount); // Simplified repayment (no interest)

        assertEq(vault.totalBorrowed(), 0, "Total borrowed should be zero after repayment");
        assertEq(vault.totalAssets(), 1000 * 10 ** 18, "Total assets should be restored");
        vm.stopPrank();
    }

    // Test convertToAssets and convertToShares
    function testConvertFunctions() public {
        vm.startPrank(user);
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 shares = vault.deposit(depositAmount);

        uint256 assets = vault.convertToAssets(shares);
        assertEq(assets, depositAmount, "Converted assets should match deposit");

        uint256 convertedShares = vault.convertToShares(assets);
        assertEq(convertedShares, shares, "Converted shares should match original shares");
        vm.stopPrank();
    }

    // Test getShareToTokenRatio
    function testGetShareToTokenRatio() public {
        vm.startPrank(user);
        uint256 depositAmount = 1000 * 10 ** 18;
        vault.deposit(depositAmount);

        uint256 ratio = vault.getShareToTokenRatio();
        assertEq(ratio, 1e18, "Ratio should be 1:1 initially");

        vm.stopPrank();
        vm.startPrank(operator);
        avs.distributeYield(address(vault), 500 * 10 ** 18); // Add yield
        ratio = vault.getShareToTokenRatio();
        assertEq(ratio, 1.5e18, "Ratio should be 1.5 after yield");
        vm.stopPrank();
    }

    // Test edge case: Vault with zero shares
    function testVaultZeroShares() public {
        uint256 ratio = vault.getShareToTokenRatio();
        assertEq(ratio, 1e18, "Ratio should be 1:1 with zero shares");

        uint256 assets = vault.convertToAssets(100 * 10 ** 18);
        assertEq(assets, 100 * 10 ** 18, "Assets should equal shares with zero shares");

        uint256 shares = vault.convertToShares(100 * 10 ** 18);
        assertEq(shares, 100 * 10 ** 18, "Shares should equal assets with zero shares");
    }
}


/*Fokus Pengujian: 

1. Deposit/Withdraw: Menguji deposit dan penarikan, termasuk validasi saham dan error seperti ZeroAmount dan NotEnoughShares.

2. Operasi AVS: Menguji addAssets, removeAssets, dan reduceBorrowed melalui interaksi dengan YieldzAVS, serta error seperti Unauthorized dan InsufficientLiquidity.

3. Konversi dan Rasio: Menguji convertToAssets, convertToShares, dan getShareToTokenRatio, termasuk edge case saat vault kosong.

 */
