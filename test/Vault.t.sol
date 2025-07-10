//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {YieldzAVS} from "../src/YieldzAVS.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract VaultTest is Test {
    MockUSDC public usdc;
    Vault public vault;
    YieldzAVS public avs;

     event Deposit(
        address indexed account, 
        uint256 amount, 
        uint256 shares 
    );


    address public User1 = makeAddr("User1");
    address public User2 = makeAddr("User2");
    address public operator = makeAddr("operator");

    //Define state variable
    uint256 public Deposit_pertama = 1_000_000;
    uint256 public Deposit_kedua = 250_000;
    uint256 public yield = 500_000; 
    uint256 public borrow = 500_000;
    uint256 public zeroSharesAmount = 0;
    

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
        emit Deposit(User1, Deposit_pertama, Deposit_pertama);
        vault.deposit(Deposit_pertama);

        assertEq(vault.balanceOf(User1), Deposit_pertama, "User 1 should have correct shares");
        console.log("Shares User1: ", vault.balanceOf(User1));
        console.log("Total Asset : ", vault.totalAssets());
        vm.stopPrank();

        //Distribute Yield AVS 
        vm.startPrank(operator);
        usdc.mint(operator, yield);
        usdc.approve(address(avs), type(uint256).max);
        avs.distributeYield(address(vault), yield);
        assertEq(vault.totalAssets(), yield + Deposit_pertama , "Total Assets should include yield");
        console.log("-----Ada yield yang dibagikan----");
        console.log("Shares User 1: ", vault.balanceOf(User1));
        console.log("Total assets after yield: ", vault.totalAssets());
        console.log("Total apa ini: ", vault.convertToAssets(vault.totalAssets()));
        vm.stopPrank();

        //User2 deposit setelah ada Distribute Yield
        vm.startPrank(User2);
        usdc.mint(User2, Deposit_kedua);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(Deposit_kedua);
        assertEq(vault.balanceOf(User2), (Deposit_kedua * Deposit_pertama) / (Deposit_pertama + yield) , "Total Assets should include User2 Deposit");
        console.log("-----User2 deposit ke Vault------");
        console.log("Shares User 1: ", vault.balanceOf(User1));
        console.log("Shares User 1 kedua: ", vault.balanceOf(User2));
        console.log("Total Asset Saat ini : ", vault.totalAssets());
        console.log("Total Shares saat ini : ", vault.totalSupply());
        vm.stopPrank();

        //User1 Withdraw
        vm.startPrank(User1);
        vault.withdraw(vault.balanceOf(User1));
        assertEq(usdc.balanceOf(User1), 1500000, "User1 should get asset back");
        console.log("-----User1 Withdraw asset-------");    
        console.log("Shares User 1: ", vault.balanceOf(User1));
        console.log("Shares User 2: ", vault.balanceOf(User2));
        console.log("Total Asset Saat ini : ", vault.totalAssets());
        console.log("Total Shares saat ini : ", vault.totalSupply());
        console.log("Total Asset User 2 : ", vault.convertToAssets(vault.balanceOf(User2)));
        vm.stopPrank();
    }

    function test_AVSOperator() public{
        vm.startPrank(User1);
        usdc.mint(User1, Deposit_pertama);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(Deposit_pertama);
        assertEq(vault.balanceOf(User1), Deposit_pertama, "User1 should have correct shares");
        console.log("Shares User1: ", vault.balanceOf(User1));
        vm.stopPrank();

        //Test Add Asset
        vm.startPrank(operator);
        usdc.mint(operator, yield);
        usdc.approve(address(avs), type(uint256).max);

        avs.distributeYield(address(vault), yield);
        assertEq(vault.totalAssets(), Deposit_pertama + yield, "Total Assets must increase by yield");

        console.log("----vault telah ditambahkan yield-----");
        console.log("total Assets saat ini: ", vault.totalAssets());

        vm.stopPrank();

        //Remove Assets
        vm.startPrank(operator);
        usdc.mint(operator, borrow);
        usdc.approve(address(avs), type(uint256).max);

        avs.borrowFund(address(vault), operator, borrow, 0, block.timestamp + 30 days);
        assertEq(vault.totalAssets(), Deposit_pertama + yield - borrow , "Total assets should decrease by borrow amount");
        assertEq(vault.totalBorrowed(), borrow, "Total borrowed should increase");
        console.log("---operator pinjam sebesar 500_000----");
        console.log("Total borrowed: ", vault.totalBorrowed());
        console.log("Total Assets: ", vault.totalAssets());
        console.log("Assets Operator: ", usdc.balanceOf(operator)); // logika test masih salah 
        vm.stopPrank();


        //Test ReduceBorrowed
        vm.startPrank(operator);
        usdc.mint(operator, borrow);
        usdc.approve(address(vault), type(uint256).max);
        avs.repayByAVS(address(vault), operator, borrow);
        console.log("----Pasca pembayaran pinjaman Operator----");
        console.log("Total Borrowed: ", vault.totalBorrowed());
        console.log("TOtal Assets: ", vault.totalAssets());
        vm.stopPrank();
    }

    function test_ConvertAssets() public{
        vm.startPrank(User1);
        usdc.mint(User1, Deposit_pertama);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(Deposit_pertama);

        assertEq(vault.convertToAssets(Deposit_pertama), Deposit_pertama, "Converted assets should match deposit" );
        assertEq(vault.convertToShares(Deposit_pertama), Deposit_pertama, "Converted Shares should match original shares" );
        console.log("Converted assets dari Deposit_pertama: ", vault.convertToAssets(Deposit_pertama));
        console.log("Converted shares dari Deposit_pertama: ", vault.convertToShares(Deposit_pertama));

        vm.stopPrank();
    }

    function test_ShareToTokenRatio() public{
        vm.startPrank(User1);
        usdc.mint(User1, Deposit_pertama);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(Deposit_pertama);
        assertEq(vault.getShareToTokenRatio(), 1e18 , "Ration should be 1:1 initially" );
        console.log("Initial share to token ratio: ", vault.getShareToTokenRatio());
        vm.stopPrank();

        vm.startPrank(operator);
        usdc.mint(operator, yield);
        usdc.approve(address(avs), type(uint256).max);
        avs.distributeYield(address(vault), yield);
        assertEq(vault.getShareToTokenRatio(), (Deposit_pertama + yield) * 1e18 / Deposit_pertama, "Ratio should reflect yield");
        console.log("Share to token ratio after yield: ", vault.getShareToTokenRatio());
        vm.stopPrank();
    }

    function test_VaultZeroShares() public{
        assertEq(vault.getShareToTokenRatio(), 1e18, "Ratio should be 1:1 with zero shares");
        assertEq(vault.convertToAssets(zeroSharesAmount), zeroSharesAmount, "Assets should equal shares with zero shares");
        assertEq(vault.convertToShares(zeroSharesAmount), zeroSharesAmount, "Shares should equal assets with zero shares");
        console.log("Ratio with zero shares: ", vault.getShareToTokenRatio());
    }
}