// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PullPayment} from "./PullPayment.sol";
import {ReentrancyGuard} from "./ReentrancyGuard.sol";

    contract SenderFundsContract is Ownable, PullPayment, ReentrancyGuard {
        
        struct BonusInfo {
            address sender;
            address receiver;
            uint256 bonusAmount;
            uint256 startDate;
            uint256 sellByDate;
            uint256 atCondition;
            uint256 minRequestDays;
            uint256 atPrice;
            uint256 meetSalesCondition;
            uint256 postDeadlineCheck;
            uint256 fundsWithdrawn;
            address token; // Token address
        }

        uint256 private constant _IS_TRUE = 1;
        uint256 private constant _IS_FALSE = 2;
        // atCondition can be used as 1 => atOrAbove, 2=> atOrBelow 3=> Both false
        uint256 private constant _IS_NEUTRAL = 3;

        mapping(address => mapping(address => mapping(string => BonusInfo))) public bonusInfo;

        using SafeERC20 for IERC20;
        IERC20 public usdtToken;
        IERC20 public usdcToken;
        IERC20 public wbtcToken;
        IERC20 public daiToken;
        IERC20 public wethToken;

        event BonusInfoCreated(address indexed sender, address indexed receiver, string indexed propertyNumber, uint256 bonusAmount, address token);
        event FundsWithdrawn(address indexed sender, address indexed receiver, string indexed propertyNumber, uint256 bonusAmount, address token);
        event BonusInfoUpdated(address indexed sender, address indexed receiver, string indexed propertyNumber, uint256 meetSalesCondition, uint256 postDeadlineCheck);

        constructor(
            address _usdtToken,
            address _usdcToken,
            address _wbtcToken,
            address _daiToken,
            address _wethToken
        ) Ownable(msg.sender) {
            usdtToken = IERC20(_usdtToken);
            usdcToken = IERC20(_usdcToken);
            wbtcToken = IERC20(_wbtcToken);
            daiToken = IERC20(_daiToken);
            wethToken = IERC20(_wethToken);
        }

        function tokenApprove() external onlyOwner {
            usdtToken.approve(address(this), type(uint256).max);
            usdcToken.approve(address(this), type(uint256).max);
            wbtcToken.approve(address(this), type(uint256).max);
            daiToken.approve(address(this), type(uint256).max);
            wethToken.approve(address(this), type(uint256).max);
        }

        function createBonusInfo(
            address receiver,
            string memory propertyNumber,
            uint256 startDateInUnixSeconds,
            uint256 sellByDateInUnixSeconds,
            uint256 atCondition,
            uint256 minRequestDays,
            uint256 atPrice,
            uint256 bonusAmount,
            address token
        ) external payable {
            require(
                (token == address(usdtToken) || token == address(usdcToken) || token == address(wbtcToken)  || token == address(daiToken) || token == address(wethToken)) || 
                (token == address(0) && msg.value == bonusAmount && msg.value >=0),
                "Unsupported token or insufficient native funds"
            );
            require(msg.sender != receiver, "You cannot be the receiver yourself");
            require(atCondition==_IS_FALSE || atCondition==_IS_TRUE || atCondition==_IS_NEUTRAL, "atCondition can be used as 1 => atOrAbove, 2=> atOrBelow 3=> Both false");
            require(minRequestDays==_IS_FALSE || minRequestDays==_IS_TRUE , "Minimum request Date can be 1 for 30 days and 2 for 60 days");
            require(sellByDateInUnixSeconds > startDateInUnixSeconds, "End date must be greater than start date");
            BonusInfo storage info = bonusInfo[msg.sender][receiver][propertyNumber];
            require(info.sender == address(0) || info.fundsWithdrawn == _IS_TRUE , "Either bonus info doesn't exist or Funds must be withdrawn before creating a new BonusInfo");

            if (token == address(0)){
                _asyncTransfer(msg.sender,receiver,propertyNumber, bonusAmount);
            } else
            {
            IERC20(token).safeTransferFrom(msg.sender, address(this), bonusAmount);
            }

            setBonusInfo(
                msg.sender,
                receiver,
                propertyNumber,
                (token == address(0)) ? msg.value : bonusAmount,
                startDateInUnixSeconds,
                sellByDateInUnixSeconds,
                atCondition,
                minRequestDays,
                atPrice,
                token
            );

            emit BonusInfoCreated(msg.sender, receiver, propertyNumber, bonusAmount, token);
        }

        function withdrawFundsSender(address Sender, address Receiver, string memory propertyNumber) external nonReentrant {
            BonusInfo storage info = bonusInfo[Sender][Receiver][propertyNumber];
            require(info.sender != address(0), "No active bonus for this sender.");
            require(info.fundsWithdrawn != _IS_TRUE, "The bonus has already been paid out.");
            require(info.postDeadlineCheck == _IS_TRUE, "Post deadline check not performed.");
            require(info.meetSalesCondition!= _IS_TRUE, "The sales conditions are met for Receiver.");

            info.fundsWithdrawn = _IS_TRUE;

            if (info.token == address(0)) {
                withdrawPayments(payable(info.sender), Sender, Receiver, propertyNumber);
            } else {
                IERC20(info.token).safeTransferFrom(address(this), info.sender, info.bonusAmount);
            }

            emit FundsWithdrawn(Sender, Receiver, propertyNumber, info.bonusAmount, info.token);
        }

        function withdrawFundsReceiver(address Sender, address Receiver, string memory propertyNumber) external nonReentrant {
            BonusInfo storage info = bonusInfo[Sender][Receiver][propertyNumber];
            require(info.receiver != address(0), "No active bonus for this sender.");
            require(info.fundsWithdrawn != _IS_TRUE, "The bonus has already been paid out.");
            require(info.meetSalesCondition == _IS_TRUE, "Sales condition isn't met");

            info.fundsWithdrawn = _IS_TRUE;

            if (info.token == address(0)) {
                withdrawPayments(payable(info.receiver), Sender, Receiver, propertyNumber);
            } else {
                IERC20(info.token).safeTransferFrom(address(this), info.receiver, info.bonusAmount);
            }

            emit FundsWithdrawn(Sender, Receiver, propertyNumber, info.bonusAmount, info.token);
        }

        function updateBonusInfo(
            address sender,
            address receiver,
            string memory propertyNumber,
            uint256 meetSalesCondition,
            uint256 postDeadlineCheck
        ) external onlyOwner {
            BonusInfo storage info = bonusInfo[sender][receiver][propertyNumber];
            require(info.sender != address(0), "No active bonus for this sender.");

            info.meetSalesCondition = meetSalesCondition;
            info.postDeadlineCheck = postDeadlineCheck;

            emit BonusInfoUpdated(sender, receiver, propertyNumber, meetSalesCondition, postDeadlineCheck);
        }

        function setBonusInfo(
            address sender,
            address receiver,
            string memory propertyNumber,
            uint256 bonusAmount,
            uint256 startDateInUnixSeconds,
            uint256 sellByDateInUnixSeconds,
            uint256 atCondition,
            uint256 minRequestDays,
            uint256 atPrice,
            address token
        ) internal {
            bonusInfo[sender][receiver][propertyNumber] = BonusInfo({
                sender: sender,
                receiver: receiver,
                bonusAmount: bonusAmount,
                startDate: startDateInUnixSeconds,
                sellByDate: sellByDateInUnixSeconds,
                atCondition: atCondition,
                minRequestDays: minRequestDays,
                atPrice: atPrice,
                meetSalesCondition: _IS_FALSE,
                postDeadlineCheck: _IS_FALSE,
                fundsWithdrawn: _IS_FALSE,
                token: token
            });
        }

        receive() external payable {}
    }
