// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract SenderFundsContract is Ownable {
    struct BonusInfo {
        address sender;
        address receiver;
        uint256 bonusAmount;
        uint256 startDate;
        uint256 sellByDate;
        bool atOrAbove;
        bool atOrBelow;
        uint256 atPrice;
        bool meetSalesCondition;
        bool postDeadlineCheck;
        bool fundsWithdrawn;
        address token; // Token address
    }

    mapping(address => mapping(address => mapping(string => BonusInfo))) public bonusInfo;

    ERC20 public usdtToken;
    ERC20 public usdcToken;
    ERC20 public wbtcToken;

    constructor(
        address _usdtToken,
        address _usdcToken,
        address _wbtcToken
    ) Ownable(msg.sender) {
        usdtToken = ERC20(_usdtToken);
        usdcToken = ERC20(_usdcToken);
        wbtcToken = ERC20(_wbtcToken);
    }

    function createBonusInfo(
        address receiver,
        string memory propertyNumber,
        uint256 startDateInUnixSeconds,
        uint256 sellByDateInUnixSeconds,
        bool atOrAbove,
        bool atOrBelow,
        uint256 atPrice,
        uint256 bonusAmount,
        address token
    ) external payable {
        // Ensure that only specific tokens are allowed
        require(
            (token == address(usdtToken) || token == address(usdcToken) || token == address(wbtcToken)) ||
            (token == address(0) && msg.value == bonusAmount),
            "Unsupported token or insufficient native funds"
        );

        // Use transferFrom to handle token deposits
        if (token != address(0)) {
            require(ERC20(token).transferFrom(msg.sender, address(this), bonusAmount), "Token transfer failed");
        }

        require(msg.sender != receiver, "You cannot be the receiver yourself");
        require(!(atOrAbove && atOrBelow), "Both atOrAbove and atOrBelow cannot be true simultaneously");
        require(sellByDateInUnixSeconds > startDateInUnixSeconds, "End date must be greater than start date");

        BonusInfo storage info = bonusInfo[msg.sender][receiver][propertyNumber];

        // Check if BonusInfo already exists
        require(info.sender == address(0) || info.fundsWithdrawn, "Either bonus info doesn't exist or Funds must be withdrawn before creating a new BonusInfo");

        // If BonusInfo does not exist or funds are withdrawn, proceed with the creation
        setBonusInfo(
            msg.sender,
            receiver,
            propertyNumber,
            (token == address(0)) ? msg.value : bonusAmount,
            startDateInUnixSeconds,
            sellByDateInUnixSeconds,
            atOrAbove,
            atOrBelow,
            atPrice,
            token
        );
    }

    function withdrawFundsSender(address Sender,address Receiver, string memory propertyNumber) external  {
        BonusInfo storage info = bonusInfo[Sender][Receiver][propertyNumber];
        require(info.sender != address(0), "No active bonus for this sender.");
        require(!info.fundsWithdrawn, "The bonus has already been paid out.");
        require(info.postDeadlineCheck, "Post deadline check not performed.");
        require(!info.meetSalesCondition, "The sales conditions are met for Receiver.");

        if(info.token==address(0)){
            payable(info.sender).transfer(info.bonusAmount);
        }
        else{ERC20(info.token).transfer(info.sender, info.bonusAmount);} // Withdraw the deposited token
        info.fundsWithdrawn = true;
    }

    function withdrawFundsReceiver(address Sender,address Receiver, string memory propertyNumber) external  {
        BonusInfo storage info = bonusInfo[Sender][Receiver][propertyNumber];
        require(info.receiver != address(0), "No active bonus for this sender.");
        require(!info.fundsWithdrawn, "The bonus has already been paid out.");
        require(info.meetSalesCondition, "Sales condition isn't met");

        if(info.token==address(0)){
            payable(info.receiver).transfer(info.bonusAmount);
        }
        else{ERC20(info.token).transfer(info.receiver, info.bonusAmount);} // Withdraw the deposited token
        info.fundsWithdrawn = true;
    }

    function updateBonusInfo(
        address sender,
        address receiver,
        string memory propertyNumber,
        bool meetSalesCondition,
        bool postDeadlineCheck
    ) external onlyOwner {
        BonusInfo storage info = bonusInfo[sender][receiver][propertyNumber];
        require(info.sender != address(0), "No active bonus for this sender.");

        info.meetSalesCondition = meetSalesCondition;
        info.postDeadlineCheck = postDeadlineCheck;
    }

    function setBonusInfo(
        address sender,
        address receiver,
        string memory propertyNumber,
        uint256 bonusAmount,
        uint256 startDateInUnixSeconds,
        uint256 sellByDateInUnixSeconds,
        bool atOrAbove,
        bool atOrBelow,
        uint256 atPrice,
        address token
    ) internal {
        bonusInfo[sender][receiver][propertyNumber] = BonusInfo({
            sender: sender,
            receiver: receiver,
            bonusAmount: bonusAmount,
            startDate: startDateInUnixSeconds,
            sellByDate: sellByDateInUnixSeconds,
            atOrAbove: atOrAbove,
            atOrBelow: atOrBelow,
            atPrice: atPrice,
            meetSalesCondition: false,
            postDeadlineCheck: false,
            fundsWithdrawn: false,
            token: token
        });
    }

    receive() external payable {}
}
