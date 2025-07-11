// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vault} from "./Vault.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract YieldzAVS {
    error ZeroAmount();
    error NoActiveLoan();
    error InsufficientRepayment();

    struct Loan {
        uint256 amount; //jumlahtoken yang dipinjam
        uint256 interestRate; //untuk bunga
        uint256 borrowedAt; //menghitung bunga -> durasi peminjaman
        uint256 maturity; //timestamp pelunasan
    }

    //operatorLoans: Mapping yang menghubungkan alamat operator (address) dengan data pinjaman mereka (Loan). Variabel ini bersifat public, sehingga dapat diakses secara eksternal untuk melihat detail pinjaman per operator.
    //Tujuan : menyimpan detail pinjamam untuk setiap operator
    mapping(address => Loan) public operatorLoans;

    event Borrowed( 
        address indexed operator, 
        uint256 amount, 
        uint256 interestRate, 
        uint256 maturity
    );

    event Repaid(
        address indexed operator, 
        uint256 amount, 
        uint256 interest
    );

    event DistributeYield(
        address indexed vault, 
        uint256 amount
    );

    function borrowFund(address _vault, address operator, uint256 amount, uint256 interestRate, uint256 maturity)
        external
    {
        if (amount == 0) revert ZeroAmount();

        operatorLoans[operator] = Loan(amount, interestRate, block.timestamp, maturity);
        Vault(_vault).removeAssets(operator, amount);
        //address token = address(Vault(_vault).token());
        //IERC20(token).transfer(msg.sender, amount);

        emit Borrowed(operator, amount, interestRate, maturity);
    }

    function distributeYield(address _vault, uint256 amount) public {
        if (amount == 0) revert ZeroAmount();
        //Mengambil alamat token ERC20 dari Vault menggunakan fungsi token() (diasumsikan Vault memiliki getter token untuk mengembalikan alamat token).
        IERC20 token = IERC20(Vault(_vault).token());
        token.transferFrom(msg.sender, address(this), amount);
        token.approve(_vault, amount);
        Vault(_vault).addAssets(amount);

        emit DistributeYield(_vault, amount);
    }

    function repayByAVS(address _vault, address operator, uint256 amount) external {
        //mengambil data pinjaman operator dari operatorLoans
        Loan memory loan = operatorLoans[operator];

        //Menghitung bunga dengan rumus <-perlu riset lebih
        if (loan.amount == 0) revert NoActiveLoan();
        uint256 interest = (loan.amount * loan.interestRate * (block.timestamp - loan.borrowedAt)) / (365 days * 10000);
        uint256 totalRepayment = loan.amount + interest;

        //Periksa apakah amount yang dibayarkan cukup untuk menutup totalRepayment
        if (amount < totalRepayment) revert InsufficientRepayment();

        //menghapus data pinjaman operator
        delete operatorLoans[operator];

        //Membuat instance IERC20 untuk token yang digunakan oleh Vault (diambil dari Vault(_vault).token()).
        IERC20 token = IERC20(Vault(_vault).token());
        //Operator ->YieldAVS
        token.transferFrom(operator, address(this), amount);
        token.approve(_vault, amount);

        //kirim token ke Vault
        Vault(_vault).addAssets(amount);

        //mengurangi totalBorrwoed
        Vault(_vault).reduceBorrowed(loan.amount);

        emit Repaid(operator, amount, interest);
    }

    //Mengembalikan detail pinjaman untuk operator tertentu.
    function getLoanDetails(address operator) external view
        returns (uint256 amount, uint256 interestRate, uint256 borrowedAt, uint256 maturity)
    {
        Loan memory loan = operatorLoans[operator];
        return (loan.amount, loan.interestRate, loan.borrowedAt, loan.maturity);
    }
}
