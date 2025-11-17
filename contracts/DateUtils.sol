// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library DateUtils {
    function isLeapYear(uint year) internal pure returns (bool) {
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    }

    function getDaysInMonth(uint year, uint month) internal pure returns (uint) {
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) return 31;
        if (month == 4 || month == 6 || month == 9 || month == 11) return 30;
        if (month == 2) return isLeapYear(year) ? 29 : 28;
        return 0; // invalid month
    }

    function currentYear() internal view returns (uint) {
        uint daysSinceEpoch = block.timestamp / 86400;
        uint year = 1970;
        while (daysSinceEpoch >= (isLeapYear(year) ? 366 : 365)) {
            daysSinceEpoch -= (isLeapYear(year) ? 366 : 365);
            year++;
        }
        return year;
    }

    // 1..12
    function currentMonth() internal view returns (uint) {
        uint daysSinceEpoch = block.timestamp / 86400;
        uint year = 1970;
        while (daysSinceEpoch >= (isLeapYear(year) ? 366 : 365)) {
            daysSinceEpoch -= (isLeapYear(year) ? 366 : 365);
            year++;
        }
        uint month = 1;
        while (daysSinceEpoch >= getDaysInMonth(year, month)) {
            daysSinceEpoch -= getDaysInMonth(year, month);
            month++;
        }
        return month;
    }

    // 1..28/29/30/31
    function currentDay() internal view returns (uint) {
        uint daysSinceEpoch = block.timestamp / 86400;
        uint year = 1970;
        while (daysSinceEpoch >= (isLeapYear(year) ? 366 : 365)) {
            daysSinceEpoch -= (isLeapYear(year) ? 366 : 365);
            year++;
        }
        uint month = 1;
        while (daysSinceEpoch >= getDaysInMonth(year, month)) {
            daysSinceEpoch -= getDaysInMonth(year, month);
            month++;
        }
        return daysSinceEpoch + 1;
    }

    // Pomocná – převede Y/M/D na unix timestamp (00:00:00 UTC)
    function toTimestamp(uint year, uint month, uint day) internal pure returns (uint) {
        require(month >= 1 && month <= 12, "Invalid month");
        require(day >= 1 && day <= getDaysInMonth(year, month), "Invalid day");
        uint daysE = 0;

        for (uint y = 1970; y < year; y++) {
            daysE += isLeapYear(y) ? 366 : 365;
        }
        for (uint m = 1; m < month; m++) {
            daysE += getDaysInMonth(year, m);
        }
        daysE += (day - 1);
        return daysE * 86400;
    }

    function getNextPaymentTimestamp(uint paymentDueDate) internal view returns (uint256) {
        uint y = currentYear();
        uint m = currentMonth();
        uint d = currentDay();

        uint dimThis = getDaysInMonth(y, m);
        require(paymentDueDate >= 1 && paymentDueDate <= dimThis, "Invalid payment date");

        if (d <= paymentDueDate) {
            // tento měsíc
            return toTimestamp(y, m, paymentDueDate);
        } else {
            // příští měsíc
            uint ny = y;
            uint nm = m + 1;
            if (nm == 13) { nm = 1; ny++; }
            uint dimNext = getDaysInMonth(ny, nm);
            uint targetDay = paymentDueDate > dimNext ? dimNext : paymentDueDate;
            return toTimestamp(ny, nm, targetDay);
        }
    }
}
