// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Vault is ERC20 {
    IERC20 public immutable token;

    constructor(address _token) ERC20("Yield Vault", "YVAULT") {
        token = IERC20(_token);
    }

    function deposit(uint256 amount) public {
        // shares = amount * total shares / total assets
        uint256 shares = 0;
        uint256 totalAssets = token.balanceOf(address(this));
        uint256 totalShares = totalSupply();

        if (totalShares == 0) {
            shares = amount;
        } else {
            shares = amount * totalShares / totalAssets;
        }

        _mint(msg.sender, shares);
        token.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 shares) public {
 
      uint256 totalShares = totalSupply();
      uint256 totalAssets = token.balanceOf(address(this));
      uint256 amount = shares * totalAssets / totalShares;

      _burn(msg.sender, shares);
      token.transfer(msg.sender, amount);
    }

    function distributeYield(uint256 amount) public {
        token.transferFrom(msg.sender, address(this), amount);
    }
 
}