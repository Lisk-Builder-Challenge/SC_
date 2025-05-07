// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Vault is ERC20 {
    error NotAVS();

    IERC20 public immutable token;

    // internal accounting
    uint256 public totalAssets;
    uint256 public totalBorrowed;

    address public avs;

    constructor(address _token, address _avs) ERC20("Yield Vault", "YVAULT") {
        token = IERC20(_token);
        avs = _avs;
    }

    function deposit(uint256 amount) public {
        // shares = amount * total shares / total assets
        uint256 shares = 0;
        totalAssets += amount;
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
        uint256 amount = shares * totalAssets / totalShares;

        totalAssets -= amount;
        _burn(msg.sender, shares);
        token.transfer(msg.sender, amount);
    }

    function distributeYield(uint256 amount) public {
        totalAssets += amount;
        token.transferFrom(msg.sender, address(this), amount);
    }

    function borrowByAVS(uint256 amount) public {
        if (msg.sender != avs) revert NotAVS();
        totalBorrowed += amount;
        token.transfer(msg.sender, amount);
    }
}
