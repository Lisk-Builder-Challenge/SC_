// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vault} from "./Vault.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract YieldzAVS {
    error ZeroAmount();
    error NoActiveLoan();
    error InsufficientRepayment();

    struct Loan{
        uint256 amount; //jumlahtoken yang dipinjam
        uint256 interestRate; //untuk bunga
        uint256 borrowedAt; //menghitung bunga -> durasi peminjaman
        uint256 maturity; //timestamp pelunasan
    }

    //operatorLoans: Mapping yang menghubungkan alamat operator (address) dengan data pinjaman mereka (Loan). Variabel ini bersifat public, sehingga dapat diakses secara eksternal untuk melihat detail pinjaman per operator.
    //Tujuan : menyimpan detail pinjamam untuk setiap operator
    mapping(address => Loan) public operatorLoans;

    //operator meminjam
    event Borrowed(
        address indexed operator,
        uint256 amount,
        uint256 interestRate, //tingkat bunga dalam basis poin
        uint256 maturity
    );

    //operator melunasi
    event Repaid(
        address indexed operator,
        uint256 amount,
        uint256 interest //bunga yang harus dibayar
    );

    //hasil(yield) didistribusikan ke kontrak vault
    event DistributeYield(
        address indexed vault,
        uint256 amount
    );

    function borrowFund(address _vault, address operator, uint256 amount, uint256 interestRate, uint256 maturity) external {
        if (amount == 0) revert ZeroAmount();

        //memperbarui operatorLoans dengan data pinjama baru
        operatorLoans[operator] = Loan(amount, interestRate, block.timestamp, maturity); 
        //Memanggil removeAssets(operator, amount) pada kontrak Vault untuk mentransfer amount token ke operator dan memperbarui state Vault (totalAssets dan totalBorrowed).
        Vault(_vault).removeAssets(operator, amount);
        // address token = address(Vault(_vault).token());
        // IERC20(token).transfer(msg.sender, amount);

        emit Borrowed(operator, amount, interestRate, maturity);
    }

    function distributeYield(address _vault, uint256 amount) public {
        if (amount == 0) revert ZeroAmount();
        //Mengambil alamat token ERC20 dari Vault menggunakan fungsi token() (diasumsikan Vault memiliki getter token untuk mengembalikan alamat token).
        IERC20 token = IERC20(Vault(_vault).token());
        //Mentransfer amount token dari msg.sender ke kontrak YieldzAVS menggunakan transferFrom. Ini memerlukan msg.sender telah memberikan allowance ke YieldzAVS.
        token.transferFrom(msg.sender, address(this), amount);
        //Memberikan persetujuan (approve) kepada Vault untuk mengambil amount token dari YieldzAVS.
        token.approve(_vault, amount);
        //Memanggil addAssets di Vault untuk mentransfer token ke Vault dan memperbarui totalAssets.
        Vault(_vault).addAssets(amount);

        emit DistributeYield(_vault, amount);


        // address token = address(Vault(_vault).token());
        // IERC20(token).transferFrom(msg.sender, address(this), amount);
        // IERC20(token).approve(address(_vault), amount);
        // Vault(_vault).distributeYield(amount);
    }

    function repayByAVS(address _vault, address operator, uint256 amount) external {
        //mengambil data pinjaman operator dari operatorLoans
        Loan memory loan = operatorLoans[operator];
        
        //Menghitung bunga dengan rumus <-perlu riset lebih
        if(loan.amount == 0) revert NoActiveLoan();
        uint256 interest = (loan.amount * loan.interestRate * (block.timestamp - loan.borrowedAt)) / (365 days * 10000);
        uint256 totalRepayment = loan.amount + interest;

        //Periksa apakah amount yang dibayarkan cukup untuk menutup totalRepayment
        if(amount < totalRepayment) revert InsufficientRepayment();

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
    function getLoanDetails(address operator) external view returns (uint256 amount, uint256 interestRate, uint256 borrowedAt, uint256 maturity) {
    Loan memory loan = operatorLoans[operator];
    return (loan.amount, loan.interestRate, loan.borrowedAt, loan.maturity);
    }
}
