// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {YieldzAVS} from "../src/YieldzAVS.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract VaultTest is Test {
    Vault public vault;
    YieldzAVS public yieldzAVS;
    MockUSDC public mockUSDC;

   address operator1 = makeAddr("operator1");

    function setUp() public {
        mockUSDC = new MockUSDC();
        yieldzAVS = new YieldzAVS();
        vault = new Vault(address(mockUSDC), address(yieldzAVS));
    }

    function test_deposit() public {
        mockUSDC.mint(address(this), 1_000_000);
        mockUSDC.approve(address(vault), 1_000_000);
        vault.deposit(1_000_000);
        assertEq(vault.totalAssets(), 1_000_000);
        console.log("balance :", vault.balanceOf(address(this)));

        // AVS
        vm.startPrank(operator1);
        yieldzAVS.borrowFund(address(vault), 1_000_000);
        assertEq(vault.totalBorrowed(), 1_000_000);

        // Distribute yield
        IERC20(address(mockUSDC)).approve(address(yieldzAVS), 1_000_000);
        yieldzAVS.distributeYield(address(vault), 1_000_000);
        assertEq(vault.totalAssets(), 2_000_000);
    }

    function test_withdraw() public {
        mockUSDC.mint(address(this), 1_000_000);
        mockUSDC.approve(address(vault), 1_000_000);
        vault.deposit(1_000_000);
        assertEq(vault.totalAssets(), 1_000_000);

        // Store the initial share balance
        uint256 initialShares = vault.balanceOf(address(this));
        console.log("Initial shares:", initialShares);
        //console.log("Balance:", vault.balanceOf(address(this)));

        // Withdraw half of your shares
        uint256 halfShares = initialShares / 2;
        vault.withdraw(halfShares);
        console.log("Remaining shares:", vault.balanceOf(address(this)));

        // Withdraw remaining shares
        vault.withdraw(vault.balanceOf(address(this)));
        assertEq(vault.totalAssets(), 0);
    }

    function test_error() public {
        mockUSDC.mint(address(this), 1_000_000);
        mockUSDC.approve(address(vault), 1_000_000);
        vm.expectRevert(Vault.ZeroAmount.selector);
        vault.deposit(0);
    }

    function test_error_withdraw() public {
        mockUSDC.mint(address(this), 1_000_000);
        mockUSDC.approve(address(vault), 1_000_000);
        vault.deposit(1_000_000);
        console.log("balance: ", vault.balanceOf(address(this)));
        vm.expectRevert(Vault.NotEnoughShares.selector); // harus diatas persis dari logika yang ingin di-expect
        vault.withdraw(1_500_000);
    }
}
