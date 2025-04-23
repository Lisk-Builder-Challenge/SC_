// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vault} from "./Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract YieldzAVS {

  Vault public vault;

    constructor(address _vault) {
        vault = Vault(_vault);
    }
  
    function manageFund(address _vault, uint256 amount) public {
       // TODO: Implement the logic to manage the fund
    }

    function distributeYield(address _vault, uint256 amount) public {
       IERC20(_vault).transferFrom(msg.sender, address(this), amount);
       IERC20(_vault).approve(address(_vault), amount);
       vault.distributeYield(amount);
    }
}
