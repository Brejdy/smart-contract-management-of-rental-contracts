// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library DateUtils {
    function getDaysInMonth(uint year, uint month) internal pure returns (uint) {
        if ((month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12)){
            return 31;
        } else if (month == 4 || month ==6 || month == 9 || month == 11) {
            return 30;
        } else if (month == 2) {
            if ((year % 4 == 0 || year % 100 != 0) || (year % 400 == 0)) {
                return 29;
            } else {
                return 28;
            }
        } 
        return 0;        
    }

    function isLeapYear(uint year) internal pure returns(bool) {
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    }

    function daysToTimestamp(uint year, uint month, uint day) internal pure returns (uint) {
        uint timestamp = 0;
        for (uint i = 1970; i < year; i++) {
            timestamp += isLeapYear(i) ? 366 : 365;
        }
        for (uint i = 1; i < month; i++) {
            timestamp += getDaysInMonth(year, i);
        }
        timestamp += (day - 1);

        return timestamp * 86400;
    }

    function getNextPaymentTimestamp(uint paymentDay) public view returns (uint) {
        uint currentTimestamp = block.timestamp;
        uint daysSinceEpoch = currentTimestamp / 86400;

        uint year = 1970;
        uint remainingDays = daysSinceEpoch;
        while (remainingDays >= (isLeapYear(year) ? 366 : 365)) {
            remainingDays -= (isLeapYear(year) ? 366 : 365);
            year++;
        }

        uint month = 1;
        while (remainingDays >= getDaysInMonth(year, month)) {
            remainingDays -= getDaysInMonth(year, month);
            month++;
        }

        if(remainingDays + 1 > paymentDay) {
            month++;
            if (month > 12) {
                year++;
                month = 1;
            }
        }

        uint timestampStartOfNextMonth = daysToTimestamp(year, month, 1);
        uint paymentTimestamp = timestampStartOfNextMonth + (paymentDay - 1) * 86400;

        return paymentTimestamp;
    }   
}