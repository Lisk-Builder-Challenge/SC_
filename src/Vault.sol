// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract Vault is ERC20, ReentrancyGuard {
    error NotAVS();
    error NotEnoughShares();
    error ZeroAmount();
    error NothingToShares();
    error Unauthorized();
    error InsufficientLiquidity();

    event Deposit(
        address indexed account, 
        uint256 amount, 
        uint256 shares 
    );

    event Withdraw(
        address indexed user,
        uint256 shares,
        uint256 amount  
    );

    event AssetsAdded(uint256 amount);
    event AssetsRemoved(uint256 amount);

    IERC20 public immutable token;
    address public immutable avs;

    // total token yang dikelola vault
    uint256 public totalAssets; 
    // total token yang dipinjam AVS
    uint256 public totalBorrowed; 

    constructor(address _token, address _avs) ERC20("Yield Vault", "YVAULT") {
        token = IERC20(_token);
        avs = _avs;
    }

    function deposit(uint256 amount) public nonReentrant returns (uint256) {
        if (amount == 0) revert ZeroAmount();
        uint256 shares = convertToShares(amount);
        uint256 totalShares = totalSupply();
        if (totalShares == 0 || totalAssets == 0){
            shares = amount;
        } else {
            shares = amount * totalShares / totalAssets;
        }
        totalAssets += amount;

        _mint(msg.sender, shares);

        token.transferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, shares); 
        return shares;
    }

    function withdraw(uint256 shares) public nonReentrant{
        if (shares > balanceOf(msg.sender)) revert NotEnoughShares();
        if (shares <= 0) revert NothingToShares();

        // Hitung token yang akan ditarik
        uint256 totalShares = totalSupply();
        uint256 amount = convertToAssets(shares);

        // Update totalAssets
        totalAssets -= amount;
        _burn(msg.sender, shares);
        token.transfer(msg.sender, amount);

        emit Withdraw(msg.sender, shares, amount);
    }

    //converts share tokens to actual tokens
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 totalShares = totalSupply();
        if (totalShares == 0) return shares;
        return (shares * totalAssets) / totalShares;
    }

    //Convert tokens to share tokens
    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 totalShares = totalSupply();
        if (totalShares == 0) return assets;
        return (assets * totalShares) / totalAssets; 
    }

    // Returns the ratio of shares to tokens in 18 decimals (e.g., 1e18 = 1 token per share) <- perlu riset lebih lanjut
    function getShareToTokenRatio() external view returns (uint256) {
        uint256 totalShares = totalSupply();
        if (totalShares == 0) return 1e18; // 1:1 jika belum ada shares
        return (totalAssets * 1e18) / totalShares; // Dalam 18 desimal
    }

    //Memungkinkan kontrak YieldzAVS menambahkan aset ke Vault (misalnya, dari distribusi hasil atau pembayaran pinjaman).
    function addAssets(uint256 amount) external {
        if(msg.sender != avs) revert Unauthorized();
        if(amount == 0 ) revert ZeroAmount();
        totalAssets += amount;
        //transfer amount token dari msg.sender(Yield AVS) -> KONTRAK vault
        token.transferFrom(msg.sender, address(this), amount);

        emit AssetsAdded(amount);
    }

    //Memungkinkan kontrak YieldzAVS mengambil aset dari Vault untuk peminjamanu
    function removeAssets(address operator, uint256 amount) external {
        if (msg.sender != avs) revert Unauthorized();
        if (amount > totalAssets - totalBorrowed) revert InsufficientLiquidity();
        totalBorrowed += amount;
        totalAssets -= amount;

        token.transfer(operator, amount);
        emit AssetsRemoved(amount);
    }

    //Mengurangi jumlah pinjaman yang tercatat di totalBorrowed, dipanggil oleh YieldzAVS saat pinjaman dilunasi.
    function reduceBorrowed(uint256 amount) external{
        if(msg.sender != avs) revert Unauthorized();
        if(amount == 0 ) revert ZeroAmount();
        totalBorrowed -= amount;
    }
}
