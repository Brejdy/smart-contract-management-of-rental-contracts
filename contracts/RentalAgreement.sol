// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./DateUtils.sol";

contract RentalAgreement is ReentrancyGuard {
    using DateUtils for uint256;

    address public landlord;
    address public tenant;
    uint256 public rentAmount;
    uint256 public depositAmount;
    string public contractIPFSHash;
    bool public isStabelcoinPayment;
    address public stabelcoinAddress;
    AggregatorV3Interface internal priceFeed;
    uint256 public depositBalance;
    uint256 public depositStartTime;
    uint256 public deductedAmount;
    uint256 public paymentDueDate;
    uint256 public warningCount;
    uint256 public amountOwed;
    bool public pendingSevereBreachWarning;
    uint256 public terminationTimeStamp;
    uint256 public contractEndDate;
    uint256 public leaseStartTimestamp;
    bool public renewalRequested;
    bool public renewalApproved;
    mapping(address => bool) public autoPaymentApproved;
    bool public earlyTerminationRequestedByLandlord;
    uint256 public paymentDate;

    enum RentalStatus {
        Active,
        Terminated,
        PendingTermination
    }
    RentalStatus public rentalStatus;

    struct PaymentRecord {
        uint256 timestamp;
        uint256 amount;
        bool stablecoin;
    }

    PaymentRecord[] public paymentHistory;

    event ContractSigned(
        address indexed landlord,
        address indexed tenant,
        string ipfsHash
    );
    event RentPaid(address indexed tennat, uint256 amount, bool stablecoin);
    event ContractTerminated(address indexed landlord, string reason);
    event DepositPaid(address indexed tenant, uint256 amount, bool stablecoin);
    event DepositReturned(address indexed tenant, uint256 amount);
    event DepositDeducted(
        address indexed landlord,
        uint256 amount,
        string reason
    );
    event SevereBreachWarningRequested(address indexed tenant);
    event SevereBreachWarningIssued(
        address indexed tenant,
        uint256 warningCount
    );
    event TerminationScheduled(uint256 terminationDate);
    event ContractExpirationWarning(uint256 monthsLeft);
    event ContractRenewed(uint256 contractEndDate);
    event ContractRenewalRequested(address indexed landlord);
    event PaymentMissed(address indexed tenant, uint256 missedAmount);
    event PaymentDueDateUpdate(uint256 nextPaymentDate);
    event Debug(uint256 val);


    modifier onlyLandlord() {
        require(
            msg.sender == landlord,
            "Only landlord can perform this action"
        );
        _;
    }

    modifier onlyTenant() {
        require(msg.sender == tenant, "Only Tenant can perform this action");
        _;
    }

    constructor(
        address _tenant,
        uint256 _rentAmount,
        uint256 _depositAmount,
        string memory _contractIPFSHash,
        bool _isStablecoinPayment,
        address _stablecoinAddress,
        address _priceFeed,
        uint256 _paymentDueDate
    ) {
        require(_tenant != address(0), "Invalid tenant address");
        require(_rentAmount > 0, "Rent amount must be greater than 0");
        require(_depositAmount >= 0, "Deposit amount must be non-negative");
        require(bytes(_contractIPFSHash).length > 0, "IPFS hash must be set");

        landlord = msg.sender;
        tenant = _tenant;
        rentAmount = _rentAmount;
        depositAmount = _depositAmount;
        contractIPFSHash = _contractIPFSHash;
        isStabelcoinPayment = _isStablecoinPayment;
        stabelcoinAddress = _stablecoinAddress;
        priceFeed = AggregatorV3Interface(_priceFeed);
        rentalStatus = RentalStatus.Active;
        depositStartTime = block.timestamp;
        deductedAmount = 0;
        paymentDueDate = _paymentDueDate;
        warningCount = 0;
        amountOwed = 0;
        pendingSevereBreachWarning = false;
        terminationTimeStamp = 0;
        leaseStartTimestamp = block.timestamp;
        contractEndDate = block.timestamp + 365 days;

        emit ContractSigned(landlord, tenant, contractIPFSHash);
    }

    function getLatestPrice() public pure returns (uint256) {
        //(, int256 price, , , ) = priceFeed.latestRoundData();
        //return uint256(price * 10**8);
        return 2000*10**8;
    }

    function authorizeAutoPayment() external onlyTenant {
        autoPaymentApproved[msg.sender] = true;
    }

    function revokeAutoPayment() external onlyTenant {
        autoPaymentApproved[msg.sender] = false;
    }

    function processAutoPayment() external onlyLandlord {
        require(autoPaymentApproved[tenant], "Auto payment not authorized");
        require(rentalStatus == RentalStatus.Active, "Contract is not active");

        uint256 amountToPay = rentAmount;
        require(
            IERC20(stabelcoinAddress).transferFrom(
                tenant,
                landlord,
                amountToPay
            ),
            "Auto pay failed"
        );

        paymentHistory.push(PaymentRecord(block.timestamp, amountToPay, true));
        emit RentPaid(tenant, amountToPay, true);
    }

    function checkAndUpdateNextPayment() public {
        uint256 nextPaymentTimestamp = DateUtils.getNextPaymentTimestamp(
            paymentDate
        );

        if (block.timestamp > nextPaymentTimestamp) {
            amountOwed += rentAmount;
            emit PaymentMissed(tenant, rentAmount);
        }

        emit PaymentDueDateUpdate(nextPaymentTimestamp);
    }

    function payRent() external payable onlyTenant nonReentrant {
        require(
            rentalStatus != RentalStatus.Terminated,
            "Rental contract is not active"
        );

        //checkAndUpdateNextPayment();

        uint256 amountToPay;
        if (isStabelcoinPayment) {
            amountToPay = rentAmount;
            require(
                IERC20(stabelcoinAddress).transferFrom(
                    msg.sender,
                    landlord,
                    amountToPay
                ),
                "Stablecoin payment failed"
            );
        } else {
            uint256 ethPrice = getLatestPrice();
            amountToPay = (rentAmount * 1e26) / ethPrice;
            require(msg.value >= amountToPay, "Insufficent ETH sent");

            payable(landlord).transfer(amountToPay);

            if (msg.value > amountToPay) {
                uint256 excess = msg.value - amountToPay;
                payable(msg.sender).transfer(excess);
            }

        }
        if (amountOwed <= amountToPay) {
            amountOwed = 0;
        } else {
            amountOwed -= amountToPay;
        }

        paymentHistory.push(
            PaymentRecord(block.timestamp, amountToPay, isStabelcoinPayment)
        );
        emit RentPaid(msg.sender, amountToPay, isStabelcoinPayment);
    }

    function checkContractExpiration() external {
        require(rentalStatus == RentalStatus.Active || rentalStatus == RentalStatus.PendingTermination, "Contract is not active");
        uint256 timeLeft = contractEndDate - block.timestamp;
        if (timeLeft == 60 days || timeLeft == 30) {
            emit ContractExpirationWarning(timeLeft / 86400);
        } else if (timeLeft >= 14 days) {
            emit ContractExpirationWarning(timeLeft / 86400);
        }
    }

    function getPaymentHistory()
        external
        view
        returns (PaymentRecord[] memory)
    {
        return paymentHistory;
    }

    function requestWarning() external onlyLandlord {
        require(
            block.timestamp >
                DateUtils.getNextPaymentTimestamp(paymentDate) + 7 days,
            "Warning not applicable yet"
        );
        pendingSevereBreachWarning = true;
        emit SevereBreachWarningRequested(tenant);
    }

    function confirmWarning() external onlyLandlord {
        require(pendingSevereBreachWarning, "No pending warning to confirm");
        warningCount++;
        pendingSevereBreachWarning = false;
        emit SevereBreachWarningIssued(tenant, warningCount);
    }

    function payDeposit() external payable onlyTenant nonReentrant {
        require(
            rentalStatus == RentalStatus.Active, "Rental contract is not active");

        uint256 amountToPay;
        if (isStabelcoinPayment) {
            require(msg.value == 0, "No ETH required for stablecoin deposit");
            amountToPay = depositAmount;
            require(IERC20(stabelcoinAddress).transferFrom(msg.sender, address(this), amountToPay), "Stablecoin deposit failed");
            depositBalance += amountToPay;
        } else {
            uint256 ethPrice = getLatestPrice();
            amountToPay = (depositAmount * 1e26) / ethPrice;
            require(msg.value >= amountToPay, "Insufficient ETH sent");

            uint256 excessAmount = msg.value - amountToPay;
            if (excessAmount > 0) {
                payable(msg.sender).transfer(excessAmount);
            }

            depositBalance += amountToPay;
        }

        emit DepositPaid(msg.sender, amountToPay, isStabelcoinPayment);
    }

    function deductFromDeposit(uint256 usdAmount, string memory reason)
        external
        onlyLandlord
        nonReentrant
    {
        uint256 ethPrice = getLatestPrice();
        uint256 weiAmount = (usdAmount * 1e18 * 1e8) / ethPrice;

        require(weiAmount <= depositBalance, "Deduction exceeds deposit amount");
        depositBalance -= weiAmount;
        deductedAmount += weiAmount;

        payable(landlord).transfer(weiAmount);

        emit DepositDeducted(landlord, weiAmount, reason);
    }

    function calculateUpdatedDeposit() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - depositStartTime;
        uint256 yearsElapsed = timeElapsed / 365 days;
        uint256 interestRate = getLatestInterestRate();
        uint256 updatedDeposit = depositBalance *
            (1 + (interestRate * yearsElapsed) / 100);
        return updatedDeposit;
    }

    function getLatestInterestRate() public pure returns (uint256) {
        //(, int256 rate, , , ) = priceFeed.latestRoundData();
        //return uint256(rate);
        return 3;
    }

    function returnDeposit() external onlyLandlord nonReentrant {
        require(
            rentalStatus == RentalStatus.Terminated,
            "Contract must ber terminated"
        );

        uint256 updatedDeposit = calculateUpdatedDeposit();
        uint256 returnAmount = depositBalance;
        depositBalance = 0;
        payable(tenant).transfer(updatedDeposit);

        emit DepositReturned(msg.sender, returnAmount);
    }

    function terminateContractIfNotRenewed() external {
        require(
            block.timestamp >= contractEndDate,
            "Contract has not expired yet"
        );
        require(
            !renewalApproved || !renewalRequested,
            "Contract has been renewed"
        );

        rentalStatus = RentalStatus.Terminated;
        emit ContractTerminated(landlord, "Contract expired without renewal");
    }

    function requestContractRenewal() external onlyTenant {
        require(
            rentalStatus == RentalStatus.Active,
            "Contract has already expired"
        );
        renewalRequested = true;

        emit ContractRenewalRequested(msg.sender);
    }

    function approveContractRenewal() external onlyLandlord {
        require(renewalRequested == true, "Tennant has not asked for renewal");

        renewalApproved = true;
        contractEndDate += 365 days;

        renewalRequested = false;
        renewalApproved = false;

        emit ContractRenewed(contractEndDate);
    }

    function checkTermination() external onlyLandlord {
        if (amountOwed > 3 * rentAmount) {
            terminationTimeStamp = block.timestamp + 90 days;
            rentalStatus = RentalStatus.PendingTermination;
            emit TerminationScheduled(terminationTimeStamp);
        }
    }

    function executeTermination() external onlyLandlord {
        require(
            rentalStatus == RentalStatus.PendingTermination,
            "Termination not schduled"
        );
        require(
            block.timestamp >= terminationTimeStamp,
            "Termination period not reached"
        );
        rentalStatus = RentalStatus.Terminated;
        emit ContractTerminated(
            landlord,
            "More than 3 payments were not registered. Contract is terminated."
        );
    }

    function requestTerminationByTenant() external onlyTenant {
        require(rentalStatus == RentalStatus.Active, "Contract is not Active");
        terminationTimeStamp = block.timestamp + 90 days;
        rentalStatus = RentalStatus.PendingTermination;

        emit TerminationScheduled(terminationTimeStamp);
    }

    function requestEarlyTerminationByLandLord() external onlyLandlord {
        require(
            rentalStatus == RentalStatus.PendingTermination,
            "Contract must be pending temination"
        );
        earlyTerminationRequestedByLandlord = true;
    }

    function confirmEarlyTermination() external onlyTenant {
        require(
            rentalStatus == RentalStatus.PendingTermination,
            "Contract  must be pending termination"
        );
        require(
            earlyTerminationRequestedByLandlord,
            "Landlord has not requested early termination"
        );

        rentalStatus = RentalStatus.Terminated;
        earlyTerminationRequestedByLandlord = false;

        emit ContractTerminated(
            msg.sender,
            "Contract terminated early by mutual agreement"
        );
    }

    function executeTenantTermination() external {
        require(
            rentalStatus == RentalStatus.PendingTermination,
            "Termination not scheduled"
        );
        require(
            block.timestamp >= terminationTimeStamp,
            "Termination period not reached"
        );
        require(amountOwed == 0, "All debts must be payed");

        rentalStatus = RentalStatus.Terminated;
        emit ContractTerminated(
            tenant,
            "Tenant terminated the lease agreement"
        );
    }

    function terminateContract(string memory reason) external onlyLandlord {
        rentalStatus = RentalStatus.Terminated;
        emit ContractTerminated(landlord, reason);
    }

    function getRentalStatus() public view returns (string memory) {
        if (rentalStatus == RentalStatus.Active) return "Active";
        if (rentalStatus == RentalStatus.Terminated) return "Terminated";
        return "PendingTermination";
    }
}
