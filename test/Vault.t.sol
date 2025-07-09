//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {YieldzAVS} from "../src/YieldzAVS.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {MockUSDC} from "../src/MockUp.sol";

contract VaultTest is Test {
    MockUSDC public usdc;
    Vault public vault;
    YieldzAVS public avs;

    address public User1 = makeAddr("User1");
    address public User2 = makeAddr("User2");
    address public User3 = makeAddr("User3");
    address public operator = makeAddr("operator");

    //Define state variable
    uint256 public Deposit_pertama = 1_000_000;
    uint256 public Deposit_kedua = 1_000_000;
    uint256 public yield = 500_000; 
    

    function setUp() public{
        usdc = new MockUSDC();
        avs = new YieldzAVS();
        vault = new Vault(address(usdc), address(avs));
    }

    function test_Deposit() public{
        //User1 deposit ke Vault
        vm.startPrank(User1);
        usdc.mint(User1, Deposit_pertama);
        usdc.approve(address(vault), type(uint256).max);

        vm.expectEmit(true, true, true, true, address(vault));
        emit Vault.Deposit(User1, Deposit_pertama, Deposit_pertama);
        vault.deposit(Deposit_pertama);

        assertEq(vault.balanceOf(User1), Deposit_pertama, "User 1 should have correct shares");
        console.log("Shares User1: ", vault.balanceOf(User1));
        vm.stopPrank();

        //Distribute Yield AVS 
        vm.startPrank(operator);
        usdc.mint(operator, yield);
        usdc.approve(address(avs), type(uint256).max);
        avs.distributeYield(address(vault), yield);
        assertEq(vault.totalAssets(), yield + Deposit_pertama , "Total Assets should include yield");
        console.log("Total assets after yield: ", vault.totalAssets());
        vm.stopPrank();

        //User2 deposit setelah ada Distribute Yield
        vm.startPrank(User2);
        usdc.mint(User2, Deposit_kedua);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(Deposit_kedua);
        assertEq(vault.balanceOf(User2), (Deposit_kedua * Deposit_pertama) / (Deposit_pertama + yield) , "Total Assets should include User2 Deposit");
        console.log("-----User2 deposit ke Vault------");
        console.log("Shares User 1: ", vault.balanceOf(User1));
        console.log("Shares User 2: ", vault.balanceOf(User2));
        console.log("Total Asset Saat ini : ", vault.totalAssets());
        console.log("Total Shares saat ini : ", vault.totalSupply());
        vm.stopPrank();

        //User1 Withdraw
        vm.startPrank(User1);
        vault.withdraw(vault.balanceOf(User1));
        assertEq(usdc.balanceOf(User1), vault.convertToAssets(vault.balanceOf(User1)), "User1 should get asset back");
        console.log("-----User1 Withdraw asset-------");    
        console.log("Shares User 1: ", vault.balanceOf(User1));
        console.log("Shares User 2: ", vault.balanceOf(User2));
        console.log("Total Asset Saat ini : ", vault.totalAssets());
        console.log("Total Shares saat ini : ", vault.totalSupply());
        vm.stopPrank();
    }

}