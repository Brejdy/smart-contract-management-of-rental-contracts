// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contracts/RentalAgreement.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TenantBot {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function authorize(address rentalAddress) external {
        RentalAgreement(rentalAddress).authorizeAutoPayment();
    }

    function approveToken(address tokenAddr, address spender, uint256 amount) external { 
        IERC20(tokenAddr).approve(spender, amount); 
    }

    function payDeposit(address rentalAddr) external {
        RentalAgreement(rentalAddr).payDeposit();
    }

    function setupDeposit(address tokenAddr, address rentalAddr, uint256 amount) external {
        IERC20(tokenAddr).approve(rentalAddr, amount);
        RentalAgreement(rentalAddr).payDeposit();
    }

    function setupDeductDeposit(address tokenAddr, address rentalAddr, uint256 amount) external {
        IERC20(tokenAddr).approve(rentalAddr, amount);
    }

    function initiateDeposit(address rentalAddr) external {
        RentalAgreement(rentalAddr).payDeposit();
    }

    function payRent(address rental) external {
        RentalAgreement(rental).payRent();
    }

    function approveForRental(address tokenAddr, address rentalAddr, uint256 amount) external {
        IERC20 token = IERC20(tokenAddr);
        bool success = token.approve(rentalAddr, amount);
        require(success, "ERC20 approve failed");
    }
}