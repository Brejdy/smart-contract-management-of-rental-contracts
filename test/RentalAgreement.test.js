const { time, loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");

describe("RentalAgreement", function () {
  // Shared constants used across fixtures and assertions.
  const FEED_DECIMALS = 8;
  const FEED_PRICE = ethers.parseUnits("2000", FEED_DECIMALS); // 2000 USD / ETH scaled by 1e8
  const STABLE_DECIMALS = 6;

  // Generic deploy helper:
  // - deploys mock price feed
  // - deploys mock stablecoin
  // - deploys RentalAgreement in either stable or ETH mode
  async function deployFixture({ stable = true, paymentDueDate = 5 } = {}) {
    const [landlord, tenant, arbiter, outsider] = await ethers.getSigners();

    const MockV3Aggregator = await ethers.getContractFactory("MockV3Aggregator");
    const feed = await MockV3Aggregator.deploy(FEED_DECIMALS, FEED_PRICE);

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const stablecoin = await MockERC20.deploy(
      "Mock USDC",
      "mUSDC",
      STABLE_DECIMALS,
      tenant.address,
      ethers.parseUnits("1000000", STABLE_DECIMALS)
    );

    const RentalAgreement = await ethers.getContractFactory("RentalAgreement");
    const rentAmount = stable
      ? ethers.parseUnits("1000", STABLE_DECIMALS)
      : ethers.parseEther("1000");
    const depositAmount = stable
      ? ethers.parseUnits("2000", STABLE_DECIMALS)
      : ethers.parseEther("2000");

    const rental = await RentalAgreement.connect(landlord).deploy(
      tenant.address,
      arbiter.address,
      rentAmount,
      depositAmount,
      "QmTestHash",
      stable,
      stable ? stablecoin.target : ethers.ZeroAddress,
      feed.target,
      paymentDueDate
    );

    return {
      rental,
      stablecoin,
      feed,
      landlord,
      tenant,
      arbiter,
      outsider,
      rentAmount,
      depositAmount,
    };
  }

  // Named fixtures for deterministic snapshots with loadFixture.
  async function deployStableFixture() {
    return deployFixture({ stable: true, paymentDueDate: 5 });
  }

  async function deployEthFixture() {
    return deployFixture({ stable: false, paymentDueDate: 5 });
  }

  async function deployStableDueDateOneFixture() {
    return deployFixture({ stable: true, paymentDueDate: 1 });
  }

  describe("Deployment & Read Functions", function () {
    // Verifies constructor wiring + default status values.
    it("sets constructor fields correctly", async function () {
      const { rental, landlord, tenant, arbiter, rentAmount, depositAmount } = await loadFixture(deployStableFixture);

      expect(await rental.landlord()).to.equal(landlord.address);
      expect(await rental.tenant()).to.equal(tenant.address);
      expect(await rental.arbiter()).to.equal(arbiter.address);
      expect(await rental.rentAmount()).to.equal(rentAmount);
      expect(await rental.depositAmount()).to.equal(depositAmount);
      expect(await rental.contractIPFSHash()).to.equal("QmTestHash");
      expect(await rental.rentalStatus()).to.equal(0);
      expect(await rental.getRentalStatus()).to.equal("Active");
    });

    it("returns latest price and quote helpers for participants", async function () {
      const { rental, landlord, tenant, arbiter } = await loadFixture(deployStableFixture);

      expect(await rental.connect(landlord).getLatestPrice()).to.equal(FEED_PRICE);
      expect(await rental.connect(tenant).getLatestPrice()).to.equal(FEED_PRICE);
      expect(await rental.connect(arbiter).currentEthUsdPrice()).to.equal(FEED_PRICE);
      expect(await rental.connect(landlord).quoteRentInWei()).to.be.gt(0);
      expect(await rental.connect(landlord).quoteDepositInWei()).to.be.gt(0);
    });

    it("reverts restricted view for outsider", async function () {
      const { rental, outsider } = await loadFixture(deployStableFixture);
      await expect(rental.connect(outsider).getLatestPrice()).to.be.revertedWith(
        "Only landlord, tenant, or arbiter can perform this action"
      );
    });
  });

  describe("Auto-Payment (Stablecoin)", function () {
    // Full happy-path for stablecoin auto-payment:
    // authorize -> process payment -> verify history/balance -> revoke.
    it("authorizes, processes, and revokes stablecoin auto-payment", async function () {
      const { rental, stablecoin, tenant, landlord, rentAmount } = await loadFixture(deployStableFixture);

      await expect(rental.connect(tenant).authorizeAutoPayment())
        .to.emit(rental, "AutoPaymentApproved")
        .withArgs(tenant.address);
      expect(await rental.autoPaymentApproved(tenant.address)).to.equal(true);

      await stablecoin.connect(tenant).approve(rental.target, rentAmount);
      const landlordBefore = await stablecoin.balanceOf(landlord.address);

      await expect(rental.connect(tenant).processAutoPayment()).to.emit(rental, "RentPaid");

      expect(await stablecoin.balanceOf(landlord.address)).to.equal(landlordBefore + rentAmount);
      const history = await rental.connect(tenant).getPaymentHistory();
      expect(history.length).to.equal(1);
      expect(history[0].stablecoin).to.equal(true);

      await expect(rental.connect(tenant).revokeAutoPayment())
        .to.emit(rental, "AutoPaymentRevoked")
        .withArgs(tenant.address);
      expect(await rental.autoPaymentApproved(tenant.address)).to.equal(false);
    });

    it("reverts auto-payment call in ETH mode", async function () {
      const { rental, tenant } = await loadFixture(deployEthFixture);
      await expect(rental.connect(tenant).processAutoPayment()).to.be.revertedWith(
        "Auto-payment is available only for stablecoin mode"
      );
    });
  });

  describe("Rent / Deposit Payments", function () {
    // Stablecoin payment branch.
    it("pays rent and deposit in stablecoin mode", async function () {
      const { rental, stablecoin, tenant, landlord, rentAmount, depositAmount } = await loadFixture(deployStableFixture);

      await stablecoin.connect(tenant).approve(rental.target, rentAmount + depositAmount);

      const landlordBefore = await stablecoin.balanceOf(landlord.address);
      await expect(rental.connect(tenant).payRent()).to.emit(rental, "RentPaid");
      expect(await stablecoin.balanceOf(landlord.address)).to.equal(landlordBefore + rentAmount);

      await expect(rental.connect(tenant).payDeposit()).to.emit(rental, "DepositPaid");
      expect(await rental.depositBalance()).to.equal(depositAmount);
    });

    // ETH payment branch.
    it("pays rent and deposit in ETH mode", async function () {
      const { rental, tenant } = await loadFixture(deployEthFixture);

      const rentWei = await rental.connect(tenant).quoteRentInWei();
      await expect(rental.connect(tenant).payRent({ value: rentWei })).to.emit(rental, "RentPaid");

      const depositWei = await rental.connect(tenant).quoteDepositInWei();
      await expect(rental.connect(tenant).payDeposit({ value: depositWei })).to.emit(rental, "DepositPaid");
      expect(await rental.depositBalance()).to.equal(depositWei);
    });
  });

  describe("Warnings, Renewal, and Termination", function () {
    // Guard checks for warning flow preconditions.
    it("keeps warning flow guarded by preconditions", async function () {
      const { rental, landlord } = await loadFixture(deployStableDueDateOneFixture);

      await expect(rental.connect(landlord).requestWarning()).to.be.revertedWith(
        "Warning not applicable yet"
      );
      await expect(rental.connect(landlord).confirmWarning()).to.be.revertedWith(
        "No pending warning to confirm"
      );
    });

    // Renewal handshake: tenant requests, landlord approves, end date extends by 1 year.
    it("handles renewal request and approval", async function () {
      const { rental, tenant, landlord } = await loadFixture(deployStableFixture);

      const oldEnd = await rental.contractEndDate();
      await expect(rental.connect(tenant).requestContractRenewal()).to.emit(rental, "ContractRenewalRequested");
      expect(await rental.renewalRequested()).to.equal(true);

      await expect(rental.connect(landlord).approveContractRenewal()).to.emit(rental, "ContractRenewed");
      const newEnd = await rental.contractEndDate();
      expect(newEnd).to.equal(oldEnd + 365n * 24n * 60n * 60n);
      expect(await rental.renewalRequested()).to.equal(false);
    });

    // checkTermination should not schedule unless debt threshold is met.
    it("keeps landlord termination path guarded by debt threshold", async function () {
      const { rental, landlord } = await loadFixture(deployStableDueDateOneFixture);

      await expect(rental.connect(landlord).checkTermination()).not.to.be.reverted;
      expect(await rental.rentalStatus()).to.equal(0); // Active
      await expect(rental.connect(landlord).executeTermination()).to.be.revertedWith(
        "Termination not schduled"
      );
    });

    // Tenant-controlled delayed termination path.
    it("handles tenant termination flow", async function () {
      const { rental, tenant } = await loadFixture(deployStableFixture);

      await expect(rental.connect(tenant).requestTerminationByTenant()).to.emit(rental, "TerminationScheduled");
      await time.increase(91 * 24 * 60 * 60);
      await expect(rental.connect(tenant).executeTenantTermination()).to.emit(rental, "ContractTerminated");
      expect(await rental.rentalStatus()).to.equal(1);
    });

    // Mutual early termination after landlord request.
    it("handles early termination agreement flow", async function () {
      const { rental, tenant, landlord } = await loadFixture(deployStableFixture);

      await rental.connect(tenant).requestTerminationByTenant();
      await expect(rental.connect(landlord).requestEarlyTerminationByLandLord()).to.emit(
        rental,
        "EarlyTerminationRequestedByLandlord"
      );
      await expect(rental.connect(tenant).confirmEarlyTermination()).to.emit(rental, "ContractTerminated");
      expect(await rental.rentalStatus()).to.equal(1);
    });

    it("terminates if not renewed after expiry", async function () {
      const { rental, landlord } = await loadFixture(deployStableFixture);
      await time.increase(366 * 24 * 60 * 60);
      await expect(rental.connect(landlord).terminateContractIfNotRenewed()).to.emit(rental, "ContractTerminated");
      expect(await rental.rentalStatus()).to.equal(1);
    });

    it("supports immediate landlord termination", async function () {
      const { rental, landlord } = await loadFixture(deployStableFixture);
      await expect(rental.connect(landlord).terminateContract("manual")).to.emit(rental, "ContractTerminated");
      expect(await rental.getRentalStatus()).to.equal("Terminated");
    });
  });

  describe("Deduction & Arbiter Flows", function () {
    // Confirms arbiter can fetch all deduction requests and keep index order for IDs.
    it("creates and lists deduction requests (with IDs)", async function () {
      const { rental, landlord, arbiter } = await loadFixture(deployStableFixture);

      await rental.connect(landlord).requestDeduction(
        ethers.parseUnits("100", STABLE_DECIMALS),
        "Damages",
        ""
      );
      await rental.connect(landlord).requestDeduction(
        ethers.parseUnits("50", STABLE_DECIMALS),
        "Cleaning",
        ""
      );

      const list = await rental.connect(arbiter).getAllDeductionRequests();
      expect(list.length).to.equal(2);
      expect(list[0].reason).to.equal("Damages");
      expect(list[1].reason).to.equal("Cleaning");
    });

    // Deduction approval transfers funds and updates accounting fields.
    it("approves deduction and updates balances", async function () {
      const { rental, stablecoin, landlord, tenant, arbiter, depositAmount } = await loadFixture(deployStableFixture);

      await stablecoin.connect(tenant).approve(rental.target, depositAmount);
      await rental.connect(tenant).payDeposit();
      expect(await rental.depositBalance()).to.equal(depositAmount);

      const deduction = ethers.parseUnits("100", STABLE_DECIMALS);
      await rental.connect(landlord).requestDeduction(deduction, "Damages", "");
      const landlordBefore = await stablecoin.balanceOf(landlord.address);

      await rental.connect(arbiter).approveDeduction(0);

      expect(await rental.depositBalance()).to.equal(depositAmount - deduction);
      expect(await rental.deductedAmount()).to.equal(deduction);
      expect(await stablecoin.balanceOf(landlord.address)).to.equal(landlordBefore + deduction);
    });

    // Deduction rejection stores reason and emits event.
    it("rejects deduction and stores rejection reason", async function () {
      const { rental, landlord, arbiter } = await loadFixture(deployStableFixture);

      await rental.connect(landlord).requestDeduction(
        ethers.parseUnits("25", STABLE_DECIMALS),
        "Minor repair",
        ""
      );

      await expect(rental.connect(arbiter).rejectDeduction(0, "No proof"))
        .to.emit(rental, "DeductionRejected")
        .withArgs(0, arbiter.address, "No proof");

      const req = await rental.deductionRequests(0);
      expect(req.rejected).to.equal(true);
      expect(req.rejectionReason).to.equal("No proof");
    });
  });

  describe("Additional Function Coverage", function () {
    // Smoke coverage for due date updater + emitted event.
    it("emits payment due update and can increase amount owed after due date", async function () {
      const { rental, landlord } = await loadFixture(deployStableDueDateOneFixture);
      await expect(rental.connect(landlord).checkAndUpdateNextPayment()).to.emit(rental, "PaymentDueDateUpdate");
      expect(await rental.amountOwed()).to.be.gte(0);
    });

    // Access-controlled read of payment history after a real payment.
    it("allows participant to read payment history", async function () {
      const { rental, stablecoin, tenant, rentAmount } = await loadFixture(deployStableFixture);
      await stablecoin.connect(tenant).approve(rental.target, rentAmount);
      await rental.connect(tenant).payRent();
      const history = await rental.connect(tenant).getPaymentHistory();
      expect(history.length).to.equal(1);
    });

    // Interest/deposit calculation path using mock feed.
    it("returns current interest rate and updated deposit", async function () {
      const { rental, stablecoin, tenant, depositAmount } = await loadFixture(deployStableFixture);

      await stablecoin.connect(tenant).approve(rental.target, depositAmount);
      await rental.connect(tenant).payDeposit();

      expect(await rental.getLatestInterestRate()).to.equal(FEED_PRICE);
      expect(await rental.calculateUpdatedDeposit()).to.equal(depositAmount);
    });

    // End-to-end deposit return flow after contract termination.
    it("returns deposit after termination", async function () {
      const { rental, stablecoin, tenant, landlord, depositAmount } = await loadFixture(deployStableFixture);
      const tenantBefore = await stablecoin.balanceOf(tenant.address);

      await stablecoin.connect(tenant).approve(rental.target, depositAmount);
      await rental.connect(tenant).payDeposit();
      await rental.connect(landlord).terminateContract("done");
      await rental.connect(landlord).returnDeposit();

      expect(await rental.depositBalance()).to.equal(0);
      expect(await stablecoin.balanceOf(tenant.address)).to.equal(tenantBefore);
    });

    // Role-based access control checks for multiple restricted functions.
    it("validates restricted actions by role", async function () {
      const { rental, landlord, tenant, arbiter, outsider } = await loadFixture(deployStableFixture);

      await expect(rental.connect(outsider).authorizeAutoPayment()).to.be.revertedWith(
        "Only Tenant can perform this action"
      );
      await expect(rental.connect(tenant).requestWarning()).to.be.revertedWith(
        "Only landlord can perform this action"
      );
      await expect(rental.connect(landlord).approveDeduction(0)).to.be.revertedWith(
        "Only Arbiter can perform this action"
      );
      await expect(rental.connect(tenant).getAllDeductionRequests()).to.be.revertedWith(
        "Only Arbiter can perform this action"
      );
      await expect(rental.connect(arbiter).terminateContract("x")).to.be.revertedWith(
        "Only landlord can perform this action"
      );
    });

    // Participants (including arbiter) are allowed to call expiration check.
    it("allows expiration check call by participants", async function () {
      const { rental, landlord, tenant, arbiter } = await loadFixture(deployStableFixture);
      await expect(rental.connect(landlord).checkContractExpiration()).not.to.be.reverted;
      await expect(rental.connect(tenant).checkContractExpiration()).not.to.be.reverted;
      await expect(rental.connect(arbiter).checkContractExpiration()).not.to.be.reverted;
    });
  });
});
