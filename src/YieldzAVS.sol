// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vault} from "./Vault.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract YieldzAVS {
    function borrowFund(address _vault, uint256 amount) public {
        Vault(_vault).borrowByAVS(amount);
        address token = address(Vault(_vault).token());
        IERC20(token).transfer(msg.sender, amount);
    }

    function distributeYield(address _vault, uint256 amount) public {
        address token = address(Vault(_vault).token());
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(address(_vault), amount);
        Vault(_vault).distributeYield(amount);
    }
}
