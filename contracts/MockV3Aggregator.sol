//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AggregatorV3Interface.sol";

contract MockV3Aggregator is AggregatorV3Interface {
    uint8 public immutable decimals;
    int256 private _answer;
    uint80 private _roundId;

    constructor(uint8 _decimals, int256 _initialAnswer)
    {
        decimals = _decimals;
        _answer = _initialAnswer;
        _roundId = 1;
    }

    function updateAnswer(int256 newAnswer) external {
        _answer = newAnswer;
        _roundId++;
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt, 
            uint256 updatedAt,
            uint80 answeredInRound
        )
        {
            return(_roundId, _answer, block.timestamp, block.timestamp, _roundId);
        }
}