// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "../contracts/RentalAgreement.sol";
import "../contracts/MyMockERC20.sol";
import "../contracts/TenantBot.sol";

contract RentalAgreementTests {
    RentalAgreement rental;
    MyMockERC20 token;
    TenantBot bot;

    address landlord;

    function beforeAll() public {
        // Deploy stablecoin and tenant bot contracts manually
        token = new MyMockERC20();
        bot = new TenantBot();

        // Mint funds to the TenantBot
        token.mint(address(bot), 25000 ether);

        // Deploy rental contract with the bot as tenant
        rental = new RentalAgreement(
            address(bot),       // Tenant
            250 ether,          // Rent
            500 ether,          // Deposit
            "QmHash",           // written agreement hash
            true,               // stablecoin payment
            address(token),     // stablecoin address
            address(0),         // price feed (dummy)
            block.timestamp + 7 // paymentDueDate (not relevant for tests)
        );

        landlord = address(this);

        // Simulate tenantBot approving RentalAgreement contract to spend tokens
        token.mint(address(this), 1000 ether); // give this contract tokens too for test purposes
        token.approve(address(rental), 1000 ether);
    }

    function testInitState() public {
        Assert.equal(rental.tenant(), address(bot), "Tenant should be set correctly");
        Assert.equal(rental.rentAmount(), 250 ether, "Rent amount should match");
    }

    function testApproveAutoPayment() public {
        bot.authorize(address(rental));
        bool approved = rental.autoPaymentApproved(address(bot));
        Assert.equal(approved, true, "Automatic payment should be approved");
    }

    function testPayDeposit() public {
        token.mint(address(bot), 500 ether);
        bot.setupDeposit(address(token), address(rental), 500 ether);

        uint balance = rental.depositBalance();
        Assert.equal(balance, 500 ether, "Deposit should be 500");
    }

    function testPayRent() public {
        token.mint(address(bot), 250 ether);
        bot.approveToken(address(token), address(rental), 250 ether);
        bot.payRent(address(rental));

        (uint48 ts, uint amount,bool isStable) = rental.paymentHistory(0);
        Assert.equal(amount, 250 ether, "Rent amount should match");
        Assert.equal(isStable, true, "Payment should be marked as stablecoin");
    }

    function testDeductFromDeposit() public {
        token.mint(address(bot), 500 ether);

        bot.setupDeductDeposit(address(token), address(rental), 500 ether);
        bot.initiateDeposit(address(rental));

        rental.deductFromDeposit(100, "Test deduction");

        uint balance = rental.depositBalance();
        Assert.equal(balance, 400 ether, "Deposit should be reduced correctly");
    }

    function testReturnDeposit() public {
        token.mint(address(bot), 500 ether);
        bot.approveToken(address(token), address(rental), 500 ether);
        bot.payDeposit(address(rental));

        rental.terminateContract("any");
        rental.returnDeposit();

        uint balance = rental.depositBalance();
        Assert.equal(balance, 0, "Deposit should be zero after return");
    }
}
