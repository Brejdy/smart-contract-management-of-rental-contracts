// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "../contracts/RentalAgreement.sol";
import "../contracts/MockERC20.sol";
import "../contracts/TenantBot.sol";

contract RentalAgreementTests {
    RentalAgreement rental;
    MockERC20 token;
    TenantBot bot;

    address landlord;

    function beforeAll() public {
        // Deploy stablecoin and tenant bot contracts manually
        token = new MockERC20();
        bot = new TenantBot();

        // Mint funds to the TenantBot
        token.mint(address(bot), 5_000 ether);

        // Deploy rental contract with the bot as tenant
        rental = new RentalAgreement(
            address(bot),
            250 ether,          // Rent
            500 ether,          // Deposit
            "QmHash",           // written agreement hash
            true,               // stablecoin payment
            address(token),     // stablecoin address
            address(0),         // price feed (dummy)
            0                   // paymentDueDate (not relevant for tests)
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
        bot.approveToken(address(token), address(rental), 500 ether);
        bot.payDeposit(address(rental));

        uint balance = rental.depositBalance();
        Assert.equal(balance, 500 ether, "Deposit should be 500");
    }

    function testDeductFromDeposit() public {
        uint depositInUsd = 500;
        uint deductionInUsd = 100;

        uint depositAmount = depositInUsd * 1e18;
        uint deductionAmount = deductionInUsd * 1e18;
        uint expectedBalance = depositAmount - deductionAmount;

        token.mint(address(bot), depositAmount);
        bot.approveToken(address(token), address(rental), depositAmount);
        bot.payDeposit(address(rental));

        rental.deductFromDeposit(deductionInUsd, "Test deduction");

        uint balance = rental.depositBalance();
        Assert.equal(balance, expectedBalance, "Deposit should be reduced correctly");
    }

    function testPayRent() public {
        // 1. Mint do TenantBota
        token.mint(address(bot), 250 ether);

        // 2. TenantBot sám dá approve rental kontraktu
        bot.setupStablecoin(address(token), address(rental), 250 ether);

        // 3. TenantBot volá payRent
        bot.approveAndPayRent(address(rental));

        // 4. Ověření historie plateb
        (, uint amount, bool stablecoin) = rental.paymentHistory(0);
        Assert.equal(amount, 250 ether, "Payment should be 250");
        Assert.equal(stablecoin, true, "Should be stablecoin payment");

        // 5. Ověření že landlord obdržel peníze
        uint landlordBalance = token.balanceOf(landlord);
        Assert.ok(landlordBalance >= 250 ether, "Landlord should receive payment");
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
