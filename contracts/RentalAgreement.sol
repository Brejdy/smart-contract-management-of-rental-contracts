// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RentalAgreement {
    address public landlord;
    address public tenant;
    uint public rentAmount;
    uint public depositAmount;
    string public contractIPFSHash;
    bool public isStabelcoinPayment;
    address public stabelcoinAddress;
    AggregatorV3Interface internal priceFeed;
    uint public depositBalance;
    uint public depositStartTime;
    uint public deductedAmount;
    uint public paymentDueDate;
    uint public warningCount;
    uint public amountOwed;
    bool public pendingSevereBreachWarning;
    uint public terminationTimeStamp;
    uint public contractEndDate;
    uint public leaseStartTimestamp;
    bool public renewalRequest;
    bool public renewalApproved;
    mapping(address => bool) public autoPaymentApproved;

    enum RentalStatus { Active, Terminated, PendingTermination }
    RentalStatus public rentalStatus;

    struct PaymentRecord {
        uint timestamp;
        uint amount;
        bool stablecoin;
    }

    PaymentRecord[] public paymentHistory;

    event ContractSigned(address indexed landlord, address indexed tenant, string ipfsHash);
    event RentPaid(address indexed tennat, uint amount, bool stablecoin);
    event ContractTerminated(address indexed landlord, string reason);
    event DepositPaid(address indexed tenant, uint amount, bool stablecoin);
    event DepositReturned(address indexed tenant, uint amount);
    event DepositDeducted(address indexed landlord, uint amount, string reason);
    event SevereBreachWarningRequested(address indexed tenant);
    event SevereBreachWarningIssued(address indexed tenant, uint warningCount);
    event TerminationScheduled(uint terminationDate);
    event ContractExpirationWarning(uint monthsLeft);
    event ContractRenewed(uint contractEndDate);
    event ContracRenewalRequested(address indexed landlord);

    modifier onlyLandlord() {
        require(msg.sender == landlord, "Only landlord can perform this action");
        _;
    }

    modifier onlyTenant() {
        require(msg.sender == tenant, "Only Tenant can perform this action");
        _;
    }
    
    constructor(
        address _tenant,
        uint _rentAmount,
        uint _depositAmount,
        string memory _contractIPFSHash,
        bool _isStablecoinPayment,
        address _stablecoinAddress,
        address _priceFeed,
        uint _paymentDueDate
    ) {
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
 
     function getLatestPrice() public view returns (uint) {
        (, int price, , , ) = priceFeed.latestRoundData();
        return uint(price*10**10);
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

        uint amountToPay = rentAmount;
        require(IERC20(stabelcoinAddress).transferFrom(tenant, landlord, amountToPay), "Auto pay failed");

        paymentHistory.push(PaymentRecord(block.timestamp, amountToPay, true));
        emit RentPaid(tenant, amountToPay, true);
     }

     function payRent() external payable onlyTenant {
        require(rentalStatus == RentalStatus.Active, "Rental contract is not active");

        uint amountToPay;
        if (isStabelcoinPayment) {
            amountToPay = rentAmount;
            require(IERC20(stabelcoinAddress).transferFrom(msg.sender, landlord, amountToPay), "Stablecoin payment failed");
        } else {
            uint ethPrice = getLatestPrice();
            amountToPay = (rentAmount * 1e18) / ethPrice;
            require(msg.value >= amountToPay, "Insufficent ETH sent");

            payable(landlord).transfer(amountToPay);
        }
        if (amountOwed == amountToPay) {
            amountOwed = 0;
        } else {
            amountOwed -= amountToPay;
        }

        paymentHistory.push(PaymentRecord(block.timestamp, amountToPay, isStabelcoinPayment));
        emit RentPaid(msg.sender, amountToPay, isStabelcoinPayment);
     }

     function checkContractExpiration() external {
        require(rentalStatus == RentalStatus.Active, "Contract is not active");
        uint timeLeft = contractEndDate - block.timestamp;
        if (timeLeft == 60 days || timeLeft == 30) {
            emit ContractExpirationWarning(timeLeft/86400);
        }
        else if (timeLeft >= 14 days) {
            emit ContractExpirationWarning(timeLeft/86400);
        }
     }

     function getPaymentHistory() external view returns(PaymentRecord[] memory) {
        return paymentHistory;
     }

     function getNextPaymentTimeStamp() public view returns (uint) {
        uint currentMonth = block.timestamp / 30 days;
        return (currentMonth + 1) * 30 days + paymentDueDate * 1 days;
     }

     function requestWarning() external onlyLandlord {
        require(block.timestamp > getNextPaymentTimeStamp() + 7 days, "Warning not applicable yet");
        pendingSevereBreachWarning = true;
        emit SevereBreachWarningRequested(tenant);
     }

     function confirmWarning() external onlyLandlord {
        require(pendingSevereBreachWarning, "No pending warning to confirm");
        warningCount++;
        pendingSevereBreachWarning = false;
        emit SevereBreachWarningIssued(tenant, warningCount);
     }

     function payDeposit() external payable onlyTenant {
        require(rentalStatus == RentalStatus.Active, "Rental contract is not active");

        uint amountToPay;
        if (isStabelcoinPayment) {
            amountToPay = depositAmount;
            require(IERC20(stabelcoinAddress).transferFrom(msg.sender, address(this), amountToPay), "Stablecoin deposit failed");
            
            uint excessAmount = msg.value - amountToPay;
            if(excessAmount > 0) {
                payable(msg.sender).transfer(excessAmount);
            }
        } else {
            uint ethPrice = getLatestPrice();
            amountToPay = (depositAmount * 1e18) / ethPrice;
            require(msg.value >= amountToPay, "Insufficent ETH sent");

            uint excessAmount = msg.value - amountToPay;
            if(excessAmount > 0) {
                payable(msg.sender).transfer(excessAmount);
            }
            
            depositBalance += amountToPay;
        }
        
        emit DepositPaid(msg.sender, amountToPay, isStabelcoinPayment);
     }

     function deductFromDeposit(uint amount, string memory reason) external onlyLandlord {
        require(amount <= depositBalance, "Deduction exceeds deposit amount");
        depositBalance -= amount;
        deductedAmount += amount;
        payable(landlord).transfer(amount);
        emit DepositDeducted(landlord, amount, reason);
     }

     function calculateUpdatedDeposit() public view returns (uint) {
        uint timeElapsed = block.timestamp - depositStartTime;
        uint yearsElapsed = timeElapsed / 365 days;
        uint interestRate = getLatestInterestRate();
        uint updatedDeposit = depositBalance * (1 + (interestRate * yearsElapsed) / 100);
        return updatedDeposit;
     }

     function getLatestInterestRate() public view returns (uint256) {
        (, int rate , , , ) = priceFeed.latestRoundData();
        return uint(rate);
     }
     
     function returnDeposit() external onlyLandlord {
        require(rentalStatus == RentalStatus.Terminated, "Contract must ber terminated");

        uint updatedDeposit = calculateUpdatedDeposit();
        uint returnAmount = depositBalance;
        depositBalance = 0;
        payable(tenant).transfer(updatedDeposit);
        
        emit DepositReturned(msg.sender, returnAmount);
     }

     function terminateContractIfNotRenewed() external {
        require(block.timestamp >= contractEndDate, "Contract has not expired yet");
        require(!renewalApproved || !renewalRequest, "Contract has been renewed");

        rentalStatus = RentalStatus.Terminated;
        emit ContractTerminated(landlord, "Contract expired without renewal");
     }

     function requestContractRenewal() external onlyTenant {
        require(rentalStatus == RentalStatus.Active, "Contract has already expired");
        renewalRequest = true;

        emit ContracRenewalRequested(msg.sender);
     }

     function approveContractRenewal() external onlyLandlord {
        require(renewalRequest == true, "Tennant has not asked for renewal");

        renewalApproved = true;
        contractEndDate += 365 days;

        renewalRequest = false;
        renewalApproved = false;

        emit ContractRenewed(contractEndDate);
     }

     function checkTermination() external onlyLandlord {
        if(amountOwed > 3 * rentAmount) {
            terminationTimeStamp = block.timestamp + 90 days;
            rentalStatus = RentalStatus.PendingTermination;
            emit TerminationScheduled(terminationTimeStamp);
        }
     }

     function executeTermination() external onlyLandlord {
        require(rentalStatus == RentalStatus.PendingTermination, "Termination not schduled");
        require(block.timestamp >= terminationTimeStamp, "Termination period not reached");
        rentalStatus = RentalStatus.Terminated;
        emit ContractTerminated(landlord, "More than 3 payments were not registered. Contract is terminated.");
     }

     function requestTerminationByTennant() external onlyTenant {
        require(rentalStatus == RentalStatus.Active, "Contract is not Active");
        terminationTimeStamp = block.timestamp + 90 days;
        rentalStatus = RentalStatus.PendingTermination;

        emit TerminationScheduled(terminationTimeStamp);
     }

     function executeTenantTermination() external {
        require(rentalStatus == RentalStatus.PendingTermination, "Termination not scheduled");
        require(block.timestamp >= terminationTimeStamp, "Termination period not reached");

        rentalStatus = RentalStatus.Terminated;
        emit ContractTerminated(tenant, "Tenant terminated the lease agreement");
     }

     function terminateContract(string memory reason) external onlyLandlord {
        rentalStatus = RentalStatus.Terminated;
        emit ContractTerminated(landlord, reason);
     }
}