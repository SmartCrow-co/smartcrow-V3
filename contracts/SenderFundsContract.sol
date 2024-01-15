// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract SenderFundsContract is Ownable {
    struct BonusInfo {
        address Sender;
        address Receiver;
        uint256 bonusAmount;
        uint256 startDate;
        uint256 sellByDate;
        bool atOrAbove;
        bool atOrBelow;
        uint256 atPrice;
        bool meetSalesCondition;
        bool postDeadlineCheck;
        bool fundsWithdrawn;
    }

    mapping(address => mapping(address => mapping(string => BonusInfo))) public bonusInfo;

    constructor() Ownable(msg.sender) {} // Pass msg.sender as the initial owner

    // Create a new bonus with an expected sales price
    function createSenderFund(
        address Receiver,
        string memory propertyNumber,
        uint256 startDateInUnixSeconds,
        uint256 sellByDateInUnixSeconds, 
        bool atOrAbove,
        bool atOrBelow,
        uint256 atPrice
    ) public payable {
     require(msg.value >= 0, "Deposit amount must be greater or equal to bonus amount");
     require(msg.sender != Receiver, "You cannot be the Receiver yourself");
    require(!(atOrAbove && atOrBelow), "Both atOrAbove and atOrBelow cannot be true simultaneously");
    require(sellByDateInUnixSeconds > startDateInUnixSeconds, "End date must be greater than start date");

    // Check if BonusInfo already exists
    if (bonusInfo[msg.sender][Receiver][propertyNumber].Sender == address(0)) {
        // If BonusInfo does not exist, proceed with the creation
        bonusInfo[msg.sender][Receiver][propertyNumber] = BonusInfo({
            Sender: msg.sender,
            Receiver: Receiver,
            bonusAmount: msg.value,
            startDate: startDateInUnixSeconds,
            sellByDate: sellByDateInUnixSeconds,
            atOrAbove: atOrAbove,
            atOrBelow: atOrBelow,
            atPrice: atPrice,
            meetSalesCondition: false,
            postDeadlineCheck: false,
            fundsWithdrawn: false
        });
    } else {
        // Inner require statement to check fundsWithdrawn condition
        require(bonusInfo[msg.sender][Receiver][propertyNumber].fundsWithdrawn, "Funds must be withdrawn before creating a new BonusInfo");

        // Can create new contract if funds are withdrawn
        bonusInfo[msg.sender][Receiver][propertyNumber] = BonusInfo({
            Sender: msg.sender,
            Receiver: Receiver,
            bonusAmount: msg.value,
            startDate: startDateInUnixSeconds,
            sellByDate: sellByDateInUnixSeconds,
            atOrAbove: atOrAbove,
            atOrBelow: atOrBelow,
            atPrice: atPrice,
            meetSalesCondition: false,
            postDeadlineCheck: false,
            fundsWithdrawn: false
        });
    }
    }

    // For Sender
    // Withdraw funds after the deadline
    function withdrawFundsSender(address Receiver, string memory propertyNumber) external onlyOwner {
        BonusInfo storage info = bonusInfo[msg.sender][Receiver][propertyNumber];
        require(info.Sender != address(0), "No active bonus for this sender.");
        require(!info.fundsWithdrawn, "The bonus has already been paid out.");
        require(info.postDeadlineCheck, "Post deadline check not performed.");
        require(!info.meetSalesCondition, "The sales conditions are met for Receiver.");

        payable(info.Sender).transfer(info.bonusAmount);
        info.fundsWithdrawn=true;
    }

    // For Receiver
    // Withdraw funds after the deadline
    function withdrawFundsReceiver(address Receiver, string memory propertyNumber) external onlyOwner {
        BonusInfo storage info = bonusInfo[msg.sender][Receiver][propertyNumber];
        require(info.Receiver != address(0), "No active bonus for this sender.");
        require(!info.fundsWithdrawn, "The bonus has already been paid out.");
        require(info.meetSalesCondition,"Sales condition isn't met");

        payable(info.Receiver).transfer(info.bonusAmount);
        info.fundsWithdrawn=true;
    }

    // Function to update BonusInfo's properties
    function updateBonusInfo(
        address sender,
        address receiver,
        string memory propertyNumber,
        bool meetSalesCondition,
        bool postDeadlineCheck
    ) external onlyOwner {
        BonusInfo storage info = bonusInfo[sender][receiver][propertyNumber];
        require(info.Sender != address(0), "No active bonus for this sender.");

        info.meetSalesCondition = meetSalesCondition;
        info.postDeadlineCheck = postDeadlineCheck;
    }

    receive() external payable {
    }
}
