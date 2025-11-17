// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./DateUtils.sol";

contract RentalAgreement is ReentrancyGuard {
    using DateUtils for uint256;

    address public immutable landlord;
    address public immutable tenant;
    address public immutable arbiter;
    uint256 public immutable rentAmount;
    uint256 public immutable depositAmount;
    string public contractIPFSHash;
    bool public immutable isStabelcoinPayment;
    address public immutable stabelcoinAddress;
    AggregatorV3Interface internal immutable priceFeed;
    uint256 public depositBalance;
    uint48 public immutable depositStartTime;
    uint256 public deductedAmount;
    uint48 public paymentDueDate;
    uint256 public warningCount;
    uint256 public amountOwed;
    bool public pendingSevereBreachWarning;
    uint48 public terminationTimeStamp;
    uint48 public contractEndDate;
    uint48 public leaseStartTimestamp;
    bool public renewalRequested;
    bool public renewalApproved;
    mapping(address => bool) public autoPaymentApproved;
    bool public earlyTerminationRequestedByLandlord;

    enum RentalStatus {
        Active,
        Terminated,
        PendingTermination
    }
    RentalStatus public rentalStatus;

    struct PaymentRecord {
        uint48 timestamp;
        uint256 amount;
        bool stablecoin;
    }

    struct DeductionRequest {
        uint amount;
        string reason;
        bool approval;
        bool rejected;
        string rejectionReason;
    }

    PaymentRecord[] public paymentHistory;
    DeductionRequest[] public deductionRequests;

    event ContractSigned(
        address indexed landlord,
        address indexed tenant,
        string ipfsHash
    );
    event RentPaid(
        address indexed tennat, 
        uint256 amount, 
        bool stablecoin
    );
    event ContractTerminated(address indexed landlord, string reason);
    event DepositPaid(
        address indexed tenant, 
        uint256 amount, 
        bool stablecoin
    );
    event DepositReturned(address indexed tenant, uint256 amount);
    event DepositDeducted(
        address indexed landlord,
        uint256 amount,
        string reason
    );
    event DeductionRejected(
        uint256 indexed requestId, 
        address indexed arbiter, 
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
    event ExcesRentReturned(address indexed tenant, uint amount);
    event AutoPaymentApproved(address indexed tenant);
    event AutoPaymentRevoked(address indexed tanant);
    event EarlyTerminationRequestedByLandlord();

    modifier onlyLandlord() {
        require( msg.sender == landlord, "Only landlord can perform this action");
        _;
    }

    modifier onlyTenant() {
        require(msg.sender == tenant, "Only Tenant can perform this action");
        _;
    }

    modifier onlyParticipants() {
        require(msg.sender == landlord || msg.sender == tenant, "Only landlord or tenant can perform this action;");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only Arbiter can perform this action");
        _;
    }

    constructor(
        address _tenant,
        address _arbiter,
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
        require(_paymentDueDate >= 1 && _paymentDueDate <= 31, "Invalid payment date");

        landlord = msg.sender;
        tenant = _tenant;
        arbiter = _arbiter;
        rentAmount = _rentAmount;
        depositAmount = _depositAmount;
        contractIPFSHash = _contractIPFSHash;
        isStabelcoinPayment = _isStablecoinPayment;
        stabelcoinAddress = _stablecoinAddress;
        priceFeed = AggregatorV3Interface(_priceFeed);
        rentalStatus = RentalStatus.Active;
        depositStartTime = uint48(block.timestamp);
        deductedAmount = 0;
        paymentDueDate = uint8(_paymentDueDate);
        warningCount = 0;
        amountOwed = 0;
        pendingSevereBreachWarning = false;
        terminationTimeStamp = 0;
        leaseStartTimestamp = uint48(block.timestamp);
        contractEndDate = uint48(block.timestamp + 365 days);

        emit ContractSigned(landlord, tenant, contractIPFSHash);
    }

    function getLatestPrice() public view onlyParticipants returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
        //return 2000*10**8;
    }

    function authorizeAutoPayment() external onlyTenant {
        autoPaymentApproved[msg.sender] = true;
        emit AutoPaymentApproved(tenant);
    }

    function revokeAutoPayment() external onlyTenant {
        delete autoPaymentApproved[msg.sender];
        emit AutoPaymentRevoked(tenant);
    }

    function processAutoPayment() external onlyLandlord {
        address _tenant = tenant;
        uint _rentAmount = rentAmount;

        require(autoPaymentApproved[_tenant], "Auto payment not authorized");
        require(rentalStatus == RentalStatus.Active, "Contract is not active");

        emit RentPaid(_tenant, _rentAmount, true);
        require(IERC20(stabelcoinAddress).transferFrom(_tenant, landlord, _rentAmount ), "Auto pay failed" );
        
        paymentHistory.push(PaymentRecord(uint48(block.timestamp), _rentAmount, true));
    }

    function checkAndUpdateNextPayment() public onlyParticipants {
        uint _rentAmount = rentAmount;
        uint _amountOwed = amountOwed;

        uint256 nextPaymentTimestamp = DateUtils.getNextPaymentTimestamp(paymentDueDate);

        if (block.timestamp > nextPaymentTimestamp) {
            _amountOwed = _amountOwed + _rentAmount;
            emit PaymentMissed(tenant, _rentAmount);
        }

        emit PaymentDueDateUpdate(nextPaymentTimestamp);
    }

    function payRent() external payable nonReentrant onlyTenant {
        require(
            rentalStatus != RentalStatus.Terminated,
            "Rental contract is not active"
        );

        checkAndUpdateNextPayment();

        bool _isStabelcoinPayment = isStabelcoinPayment;
        uint _rentAmount = rentAmount;
        address _landlord = landlord;
        uint _amountOwed = amountOwed;

        uint256 amountToPay;
        if (_isStabelcoinPayment) {

            amountToPay = _rentAmount;
            emit RentPaid(msg.sender, amountToPay, isStabelcoinPayment);
            require(IERC20(stabelcoinAddress).transferFrom(msg.sender, _landlord, amountToPay), "Stablecoin payment failed");
        } 
        else {
            uint256 ethPrice = getLatestPrice();
            amountToPay = (_rentAmount * 1e8) / ethPrice;
            require(msg.value >= amountToPay, "Insufficent ETH sent");

            emit RentPaid(msg.sender, amountToPay, _isStabelcoinPayment);
            payable(_landlord).transfer(amountToPay);

            if (msg.value > amountToPay && _amountOwed <= 0) {
                uint256 excess = msg.value - amountToPay;

                emit ExcesRentReturned(msg.sender, excess);
                payable(msg.sender).transfer(excess);
            }
        }

        if (_amountOwed <= amountToPay) {
            delete amountOwed;
        } else {
            amountOwed = _amountOwed - amountToPay;
        }

        paymentHistory.push(
            PaymentRecord(uint48(block.timestamp), amountToPay, _isStabelcoinPayment)
        );
    }

    function checkContractExpiration() external onlyParticipants {

        require(rentalStatus == RentalStatus.Active || rentalStatus == RentalStatus.PendingTermination, "Contract is not active");
        uint256 timeLeft = contractEndDate - block.timestamp;
        uint256 daysLeft = timeLeft / 1 days;
        if (daysLeft == 60 days || daysLeft == 30 || daysLeft >= 14 days) {
            emit ContractExpirationWarning(timeLeft / 86400);
        }
    }

    function getPaymentHistory() external view onlyParticipants returns (PaymentRecord[] memory) {
        return paymentHistory;
    }

    function requestWarning() external onlyLandlord {
        require(block.timestamp > DateUtils.getNextPaymentTimestamp(paymentDueDate) + 7 days, "Warning not applicable yet");
        pendingSevereBreachWarning = true;
        emit SevereBreachWarningRequested(tenant);
    }

    function confirmWarning() external onlyLandlord {
        require(pendingSevereBreachWarning, "No pending warning to confirm");
        warningCount++;
        delete pendingSevereBreachWarning;
        emit SevereBreachWarningIssued(tenant, warningCount);
    }

    function payDeposit() external payable nonReentrant onlyTenant {
        require(rentalStatus == RentalStatus.Active, "Rental contract is not active");

        bool _isStabelcoinPayment = isStabelcoinPayment;
        uint _depositAmount = depositAmount;
        uint _depositBalance = depositBalance;
        address _stabelcoinAddress = stabelcoinAddress;

        uint256 amountToPay;
        if (_isStabelcoinPayment) 
        {
            require(msg.value == 0, "No ETH required for stablecoin deposit");
            amountToPay = _depositAmount;

            emit DepositPaid(msg.sender, amountToPay, _isStabelcoinPayment);
            require(IERC20(_stabelcoinAddress).transferFrom(msg.sender, address(this), amountToPay), "Stablecoin deposit failed");
            depositBalance = _depositBalance + amountToPay;
        } 
        else 
        {
            uint256 ethPrice = getLatestPrice();
            amountToPay = (depositAmount * 1e8) / ethPrice;
            require(msg.value >= amountToPay, "Insufficient ETH sent");

            uint256 excessAmount = msg.value - amountToPay;

            emit DepositPaid(msg.sender, amountToPay, _isStabelcoinPayment);
            if (excessAmount > 0) 
            {
                payable(msg.sender).transfer(excessAmount);
            }

            depositBalance = _depositBalance + amountToPay;
        }
    }

    function requestDeduction(uint256 usdAmount, string memory reason, string memory rejectionReason) external onlyLandlord {
        deductionRequests.push(DeductionRequest({
            amount: usdAmount,
            reason: reason,
            approval: false,
            rejected: false,
            rejectionReason: rejectionReason
        }));
    }

    function deductFromDeposit(uint256 usdAmount, string memory reason) internal {

        bool _isStabelcoinPayment = isStabelcoinPayment;
        uint _depositBalance = depositBalance;
        uint _deductedAmount = deductedAmount;
        address _stabelcoinAddress = stabelcoinAddress;
        address _landlord = landlord;

        uint256 amountToDeduct;

        if (_isStabelcoinPayment) {
            amountToDeduct = usdAmount * 1e18;
            require(amountToDeduct <= _depositBalance, "Deduction exceeds deposit amount");

            depositBalance = _depositBalance - amountToDeduct;
            deductedAmount = _deductedAmount + amountToDeduct;

            emit DepositDeducted(_landlord, amountToDeduct, reason);
            require(IERC20(_stabelcoinAddress).transfer(_landlord, amountToDeduct), "Stablecoin transfer failed");
        } else {
            uint256 ethPrice = getLatestPrice();
            amountToDeduct = (usdAmount * 1e18 * 1e8) / ethPrice;

            require(amountToDeduct <= depositBalance, "Deduction exceeds deposit amount");

            depositBalance = _depositBalance - amountToDeduct;
            deductedAmount = _deductedAmount + amountToDeduct;

            emit DepositDeducted(_landlord, amountToDeduct, reason);
            payable(_landlord).transfer(amountToDeduct);
        }
    }

    function approveDeduction(uint256 requestId) external onlyArbiter {
        require(requestId < deductionRequests.length, "Invalid request ID");
        DeductionRequest storage req = deductionRequests[requestId];

        require(!req.approval && !req.rejected, "Request already processed");
        req.approval = true;

        deductFromDeposit(req.amount, req.reason);
    }

    function rejectDeduction(uint256 requestId, string calldata reason) external onlyArbiter {
        require(requestId < deductionRequests.length, "Invalid request ID");
        DeductionRequest storage req = deductionRequests[requestId];

        require(!req.approval && !req.rejected, "Request already processed");

        req.rejected = true;
        req.rejectionReason = reason;

        emit DeductionRejected(requestId, msg.sender, reason);
    }

    function calculateUpdatedDeposit() public view onlyParticipants returns (uint256) {
        uint256 timeElapsed = block.timestamp - depositStartTime;
        uint256 yearsElapsed = timeElapsed / 365 days;
        uint256 interestRate = getLatestInterestRate();
        uint256 updatedDeposit = depositBalance *
            (1 + (interestRate * yearsElapsed) / 100);
        return updatedDeposit;
    }

    function getLatestInterestRate() public view onlyParticipants returns (uint256) {
        (, int256 rate, , , ) = priceFeed.latestRoundData();
        return uint256(rate);
        //return 3;
    }

    function returnDeposit() external nonReentrant onlyLandlord {
        require(rentalStatus == RentalStatus.Terminated, "Contract must be terminated");

        address _tenant = tenant;

        uint256 updatedDeposit = calculateUpdatedDeposit();
        depositBalance = 0;

        if (isStabelcoinPayment)
        {
            emit DepositReturned(_tenant, updatedDeposit);
            require(IERC20(stabelcoinAddress).transfer(_tenant, updatedDeposit), "Stablecoin payment failed");
        }
        else 
        {
            emit DepositReturned(_tenant, updatedDeposit);
            payable(_tenant).transfer(updatedDeposit);
        }
    }

    function terminateContractIfNotRenewed() external onlyLandlord {
        require(block.timestamp >= contractEndDate, "Contract has not expired yet");
        require(!renewalApproved || !renewalRequested, "Contract has been renewed");

        rentalStatus = RentalStatus.Terminated;
        emit ContractTerminated(landlord, "Contract expired without renewal");
    }

    function requestContractRenewal() external onlyTenant {
        require(rentalStatus == RentalStatus.Active, "Contract has already expired");
        renewalRequested = true;

        emit ContractRenewalRequested(msg.sender);
    }

    function approveContractRenewal() external onlyLandlord {
        require(renewalRequested, "Tennant has not asked for renewal");

        renewalApproved = true;
        contractEndDate = contractEndDate + 365 days;

        delete renewalRequested;
        delete renewalApproved;

        emit ContractRenewed(contractEndDate);
    }

    function checkTermination() external onlyLandlord {
        if (amountOwed > 3 * rentAmount) {
            terminationTimeStamp = uint48(block.timestamp + 90 days);
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
        terminationTimeStamp = uint48(block.timestamp + 90 days);
        rentalStatus = RentalStatus.PendingTermination;

        emit TerminationScheduled(terminationTimeStamp);
    }

    function requestEarlyTerminationByLandLord() external onlyLandlord {
        require(
            rentalStatus == RentalStatus.PendingTermination,
            "Contract must be pending temination"
        );
        earlyTerminationRequestedByLandlord = true;
        emit EarlyTerminationRequestedByLandlord();
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
        delete earlyTerminationRequestedByLandlord;

        emit ContractTerminated(
            msg.sender,
            "Contract terminated early by mutual agreement"
        );
    }

    function executeTenantTermination() external onlyTenant {
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

    function getRentalStatus() public view onlyParticipants returns (string memory) {
        if (rentalStatus == RentalStatus.Active) return "Active";
        if (rentalStatus == RentalStatus.Terminated) return "Terminated";
        return "PendingTermination";
    }

    function _ethUsdPriceScaled() internal view returns (uint) {
        return getLatestPrice(); //chainlink price * 1e8;
    }

    function quoteRentInWei() public view onlyParticipants returns (uint) {
        uint ethPrice = _ethUsdPriceScaled();
        return (rentAmount * 1e8) / ethPrice;
    }

    function quoteDepositInWei() public view onlyParticipants returns (uint) {
        uint ethPrice = _ethUsdPriceScaled();
        return (depositAmount * 1e8) / ethPrice;
    }

    function currentEthUsdPrice() external view onlyParticipants returns (uint256) {
        return _ethUsdPriceScaled();
    }
}


//TODO: FE change landlords function deductFromDeposit to requestDeductDeposit