const RentalAgreement = artifacts.require("RentalAgreement");
const StableMock = artifacts.require("MockERC20");

contact("RentalAgreement (ETH and Stable)", accounts => {
    const [landlord, tenant, other] = accounts;

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
});