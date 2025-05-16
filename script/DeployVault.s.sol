// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {YieldzAVS} from "../src/YieldzAVS.sol";

contract DeployVaultScript is Script {
    Vault public vault;
    MockUSDC public mockUSDC;
    YieldzAVS public yieldzAVS;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        mockUSDC = new MockUSDC();
        yieldzAVS = new YieldzAVS();
        vault = new Vault(address(mockUSDC), address(yieldzAVS));

        console.log("Vault deployed at", address(vault));
        console.log("MockUSDC deployed at", address(mockUSDC));
        console.log("YieldzAVS deployed at", address(yieldzAVS));

        vm.stopBroadcast();
    }
}