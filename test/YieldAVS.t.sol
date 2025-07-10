//SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8.13;   

import {Test, console} from "forge-std/Test.sol";
import {YieldzAVS} from "../src/YieldzAVS.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {Vault} from "../src/Vault.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract YieldzAVSTest is Test {
    MockUSDC public usdc;
    Vault public vault;
    YieldzAVS public avs;

    event Borrowed( 
        address indexed operator, 
        uint256 amount, 
        uint256 interestRate, 
        uint256 maturity
    );

    address public User1 = makeAddr("User1");
    address public User2 = makeAddr("User2");
    address public operator = makeAddr("operator");

    uint256 public borrow = 1_000_000;
    uint256 public yield = 500_000;
    uint256 public interestRate = 500;
    uint256 public maturity = block.timestamp + 30 days;
    uint256 public zeroAmount = 0;

    function setUp() public {
        usdc = new MockUSDC();
        avs = new YieldzAVS();
        vault = new Vault(address(usdc), address(avs));

        usdc.mint(operator, 2_000_000);
    }

    function test_BorrowFund() public {
        //Buat skenario supaya vault sudah terisi
        vm.startPrank(User1);
        usdc.mint(User1, 1_000_000);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(1_000_000);
        vm.stopPrank();

        vm.startPrank(operator);
        usdc.approve(address(avs), type(uint256).max);
        console.log("Jumlah shares di vault \t: ", vault.totalAssets());
        console.log("Jumlah asset operator \t: ", usdc.balanceOf(operator));

        vm.expectEmit(true, true, true, true, address(avs));
        emit Borrowed(operator, borrow, interestRate, maturity);
        avs.borrowFund(address(vault), operator, borrow, interestRate, maturity);
        (uint256 amount, uint256 rate, uint256 borrowedAt, uint256 loanMaturity) = avs.getLoanDetails(operator);
        assertEq(amount, borrow, "Loan amount should match");
        console.log("Besar pinjaman \t\t: ", amount);
        assertEq(rate, interestRate, "Rate should match");
        console.log("Besar bunga \t\t\t: ", rate);
        assertEq(loanMaturity, maturity, "Maturity should match");
        console.log("Lama pinjaman \t\t: ", loanMaturity);
        console.log("----setelah operator berhasil minjam-----");
        console.log("Jumlah shares di vault\t: ", vault.totalAssets());
        console.log("Asset yang dipegang operator\t: ", usdc.balanceOf(operator));
        vm.stopPrank();
    }

    function test_BorrowFund_ZeroAmount() public {
        vm.startPrank(operator);
        vm.expectRevert(abi.encodeWithSelector(YieldAVS.zeroAmount.selector));
        avs.borrowFund(address(vault), operator, zeroAmount, interestRate, maturity);
        vm.stopPrank();
    }

}