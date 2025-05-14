// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Vault is ERC20 {
    error NotAVS();
    error NotEnoughShares();
    error ZeroAmount();

    event Deposit(address account, uint256 amount, uint256 shares, uint256 totalAssets);

    IERC20 public immutable token;

    // internal accounting
    uint256 public totalAssets;
    uint256 public totalBorrowed;

    address public avs;

    constructor(address _token, address _avs) ERC20("Yield Vault", "YVAULT") {
        token = IERC20(_token);
        avs = _avs;
    }

    function deposit(uint256 amount) public returns (uint256) {
        if (amount == 0) revert ZeroAmount();
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
        emit Deposit(msg.sender, amount, shares, totalAssets); // trigger event deposit()

        return shares;
    }

    // Mendapatkan user's Balance
    function balanceOfUnderlying(address user) public view returns (uint256) {
        uint256 shares = balanceOf(user);
        return convertToAssets(shares);
    }

    function withdraw(uint256 shares) public {
        if (shares > balanceOf(msg.sender)) revert NotEnoughShares();

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

    //converts share tokens to actual tokens
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 totalShares = totalSupply();
        if (totalShares == 0) return shares;
        return shares * totalAssets / totalShares;
    }

    //Convert tokens to share tokens
    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 totalShares = totalSupply();
        if (totalShares == 0) return assets;
        return assets * totalShares / totalAssets;
    }

    // Calculate the yield percentage
    function currentAPY() public view returns (uint256) {
        // This is a simplified example - implement your actual APY calculation
        if (totalAssets == 0) return 0;
        uint256 yieldGenerated = totalAssets - totalSupply(); // Assuming initial share price = 1
        if (yieldGenerated <= 0) return 0;
        return (yieldGenerated * 10000) / totalSupply(); // Return in basis points
    }
}
