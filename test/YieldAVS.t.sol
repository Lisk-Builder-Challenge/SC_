// SPDX-License-License-Identifier: UNLICENSED
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

contract TestYieldzAVS is Test {
    Vault vault;
    YieldzAVS avs;
    MockToken token;
    address user = address(0x1);
    address operator = address(0x2);

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

    // Test borrowByAVS
    function testBorrowByAVS() public {
        vm.startPrank(user);
        vault.deposit(1000 * 10 ** 18); // Provide liquidity
        vm.stopPrank();

        vm.startPrank(operator);
        uint256 borrowAmount = 500 * 10 ** 18;
        uint256 interestRate = 100; // 1%
        uint256 maturity = block.timestamp + 365 days;
        avs.borrowFund(address(vault), operator, borrowAmount, interestRate, maturity);

        (uint256 amount, uint256 rate, uint256 borrowedAt, uint256 loanMaturity) = avs.getLoanDetails(operator);
        assertEq(amount, borrowAmount, "Loan amount should match");
        assertEq(rate, interestRate, "Interest rate should match");
        assertEq(borrowedAt, block.timestamp, "Borrowed time should match");
        assertEq(loanMaturity, maturity, "Maturity should match");
        vm.stopPrank();
    }

    // Test borrowByAVS with zero amount should fail
    function testFailBorrowByAVSZeroAmount() public {
        vm.startPrank(operator);
        vm.expectRevert(YieldzAVS.ZeroAmount.selector);
        avs.borrowFund(address(vault), operator, 0, 100, block.timestamp + 365 days);
        vm.stopPrank();
    }

    // Test repayByAVS
    function testRepayByAVS() public {
        vm.startPrank(user);
        vault.deposit(1000 * 10 ** 18); // Provide liquidity
        vm.stopPrank();

        vm.startPrank(operator);
        uint256 borrowAmount = 500 * 10 ** 18;
        avs.borrowFund(address(vault), operator, borrowAmount, 100, block.timestamp + 365 days);

        // Simulate time passing for interest (1 year)
        vm.warp(block.timestamp + 365 days);
        uint256 interest = (borrowAmount * 100 * 365 days) / (365 days * 10000); // 1% interest
        uint256 totalRepayment = borrowAmount + interest;
        avs.repayByAVS(address(vault), operator, totalRepayment);

        (uint256 amount,,,) = avs.getLoanDetails(operator);
        assertEq(amount, 0, "Loan should be cleared after repayment");
        assertEq(vault.totalAssets(), 1000 * 10 ** 18, "Vault assets should be restored");
        vm.stopPrank();
    }

    // Test repayByAVS with no active loan should fail
    function testFailRepayByAVSNoActiveLoan() public {
        vm.startPrank(operator);
        vm.expectRevert(YieldzAVS.NoActiveLoan.selector);
        avs.repayByAVS(address(vault), operator, 500 * 10 ** 18);
        vm.stopPrank();
    }

    // Test repayByAVS with insufficient repayment should fail
    function testFailRepayByAVSInsufficientRepayment() public {
        vm.startPrank(user);
        vault.deposit(1000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(operator);
        uint256 borrowAmount = 500 * 10 ** 18;
        avs.borrowFund(address(vault), operator, borrowAmount, 100, block.timestamp + 365 days);

        vm.warp(block.timestamp + 365 days);
        vm.expectRevert(YieldzAVS.InsufficientRepayment.selector);
        avs.repayByAVS(address(vault), operator, borrowAmount / 2); // Less than required
        vm.stopPrank();
    }

    // Test distributeYield
    function testDistributeYield() public {
        vm.startPrank(operator);
        uint256 yieldAmount = 500 * 10 ** 18;
        avs.distributeYield(address(vault), yieldAmount);

        assertEq(vault.totalAssets(), yieldAmount, "Vault assets should increase by yield");
        assertEq(token.balanceOf(address(vault)), yieldAmount, "Vault should hold yield tokens");
        vm.stopPrank();
    }

    // Test distributeYield with zero amount should fail
    function testFailDistributeYieldZeroAmount() public {
        vm.startPrank(operator);
        vm.expectRevert(YieldzAVS.ZeroAmount.selector);
        avs.distributeYield(address(vault), 0);
        vm.stopPrank();
    }
}


/* Fokus Pengujian

1. Peminjaman: Menguji borrowByAVS dan validasi detail pinjaman, termasuk error ZeroAmount.

2. Pelunasan: Menguji repayByAVS dengan perhitungan bunga, termasuk error NoActiveLoan dan InsufficientRepayment.

3. Distribusi Hasil: Menguji distributeYield dan error ZeroAmount.

4. Detail Pinjaman: Menguji getLoanDetails untuk memastikan data pinjaman benar.

*/