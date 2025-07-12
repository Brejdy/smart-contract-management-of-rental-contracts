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

    // přidáno: tenant sám provede approve rentalu
    function setupStablecoin(address tokenAddr, address rentalAddr, uint256 amount) external {
        IERC20(tokenAddr).approve(rentalAddr, amount);
    }

    function payDeposit(address rentalAddr) external {
        RentalAgreement(rentalAddr).payDeposit();
    }

    function approveAndPayRent(address rentalAddr) external {
        RentalAgreement(rentalAddr).payRent();
    }
}
