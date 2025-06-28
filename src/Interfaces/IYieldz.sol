//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IYieldz is IERC20 {

    struct Loan{
        uint256 amount; 
        uint256 interestRate; 
        uint256 borrowedAt; 
        uint256 maturity; 
    }

    function borrowFund(address _vault, address operator, uint256 amount, uint256 interestRate, uint256 maturity)
        external;

    function distributeYield(address _vault, uint256 amount) external;

    function repayByAVS(address _vault, address operator, uint256 amount) external;

    function getLoanDetails(address operator) external;
}
