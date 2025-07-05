// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "../contracts/RentalAgreement.sol";
contract TenantBot {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function authorize(address rentalAddress) external {
        RentalAgreement(rentalAddress).authorizeAutoPayment();
    }

    function approveToken(address tokenAddr, address spender, uint256 amount) external {
        bool success = IERC20(tokenAddr).approve(spender,amount);
        require(success, "Approve failed");
    }

    function payDeposit(address rentalAddr) external {
        RentalAgreement(rentalAddr).payDeposit();
    }

    function payRent(address rentalAddr) external {
        RentalAgreement(rentalAddr).payRent();
    }

}
