const RentalAgreement = artifacts.require("RentalAgreement");
const StableMock = artifacts.require("MockERC20");

contract("RentalAgreement (ETH and Stable)", accounts => {
    const [landlord, tenant, other] = accounts;
    const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

    beforeEach(async () => {
        this.token = await StableMock.new("TestCoin", "TC", 18, web3.utils.toBN("1000000"));
        this.rental = await RentalAgreement.new(
            tenant,
            web3.utils.toBN("1000"),
            web3.utils.toBN("500"),
            "QmHash",
            true,
            this.token.address,
            ZERO_ADDRESS, //Price feed dummy
            0 //paymentDueDate
        );
    });

    it("approve stablecoin autoPayment", async () => {
        await this.token.approve(this.rental.address, "1000", { from: tenant });
        await this.rental.authorizeAutoPayment({ from: tenant });

        const ok = await this.rental.autoPaymentApproved(tenant);
        assert.equal(ok, true, "auto payment should be allowed");
    });

    it("execute processAutoPayment", async () => {
        await this.token.approve(this.rental.address, "1000", { from: tenant });
        await this.rental.authorizeAutoPayment({ from: tenant });
        await this.token.transfer(landlord, "0", { from: tenant });
        await this.rental.processAutoPayment({ from: landlord });

        const bal = await this.token.balanceOf(landlord);
        assert(bal.gte(web3.utils.toBN("1000")), "Landlord should receive rent");
    });

    it("should process deposit", async () => {
        await this.token.approve(this.rental.address, "500", { from: tenant });
        const tx = await this.rental.payDeposit({ from: tenant });

        const balance = await this.rental.depositBalance();
        assert.equal(balance.toString(), "500", "Deposit balance should be 500");

        assert.equal(tx.logs[0].event, "DepositPaid", "Event not emitted");
    });

    it("should deduct from deposit", async () => {
        await this.token.approve(this.rental.address, "500", { from: tenant });
        await this.rental.payDeposit({ from: tenant });

        const tx = await this.rental.deductFromDeposit("100", "Test deduction", { from: landlord});

        const balance = await this.rental.depositBalance();
        assert.equal(balance.toString(), "400", "Deposit balance should be 400");

        assert.equal(tx.logs[0].event, "DepositDeducted", "Event not emitted");
    });

    it("should process rent", async () => {
        await token.this.approve(this.rental.address, "250", { from: tenant });

        const tx = await this.rental.payRent({ from: tenant });

        assert.equal(tx.logs[0].event, "RentPaid", "RentPaid event not emitted");

        const payment = await this.rental.paymentHistory(0);
        assert.equal(payment.amount.toString(), "250", "Amount in paymentHistory should be 250");
        assert.equal(payment.stablecoin, true, "Payment should be marked as stablecoin");

        const balance = await this.token.balanceOf(landlord);
        assert.equal(balance.toString(), "250", "Landlord should have recieved 250 TC");
    });

    it("should return deposit", async () => {
        await this.token.approve(this.rental.address, "500", { from: tenant });
        await this.rental.payDeposit({ from: tenant });

        await this.rental.terminateContract("test reason", { from: landlord });

        const tx = await this.rental.returnDeposit({ from: landlord });

        const balance = await this.rental.depositBalance();
        assert.equal(balance.toString(), "0", "Deposit should be zero");

        assert.equal(tx.logs[0].event, "DepositReturned", "Event not emitted");
    });
});