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
        bool atOrAbove;
        bool atOrBelow;
        uint256 atPrice;
        bool meetSalesCondition;
        bool postDeadlineCheck;
        bool fundsWithdrawn;
        address token; // Token address
    }

    mapping(address => mapping(address => mapping(string => BonusInfo))) public bonusInfo;

    using SafeERC20 for IERC20;
    IERC20 public usdtToken;
    IERC20 public usdcToken;
    IERC20 public wbtcToken;
    IERC20 public daiToken;
    IERC20 public wethToken;

    event BonusInfoCreated(address indexed sender, address indexed receiver, string indexed propertyNumber, uint256 bonusAmount, address token);
    event FundsWithdrawn(address indexed sender, address indexed receiver, string indexed propertyNumber, uint256 bonusAmount, address token);
    event BonusInfoUpdated(address indexed sender, address indexed receiver, string indexed propertyNumber, bool meetSalesCondition, bool postDeadlineCheck);

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

    function tokenApprove(address token, uint256 amount) external onlyOwner {
        IERC20(token).approve(address(this), amount);
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
        require(
            (token == address(usdtToken) || token == address(usdcToken) || token == address(wbtcToken)  || token == address(daiToken) || token == address(wethToken)) || 
            (token == address(0) && msg.value == bonusAmount),
            "Unsupported token or insufficient native funds"
        );
        require(msg.sender != receiver, "You cannot be the receiver yourself");
        require(!(atOrAbove && atOrBelow), "Both atOrAbove and atOrBelow cannot be true simultaneously");
        require(sellByDateInUnixSeconds > startDateInUnixSeconds, "End date must be greater than start date");
        BonusInfo storage info = bonusInfo[msg.sender][receiver][propertyNumber];
        require(info.sender == address(0) || info.fundsWithdrawn , "Either bonus info doesn't exist or Funds must be withdrawn before creating a new BonusInfo");

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
            atOrAbove,
            atOrBelow,
            atPrice,
            token
        );

        emit BonusInfoCreated(msg.sender, receiver, propertyNumber, bonusAmount, token);
    }

    function withdrawFundsSender(address Sender, address Receiver, string memory propertyNumber) external nonReentrant {
        BonusInfo storage info = bonusInfo[Sender][Receiver][propertyNumber];
        require(info.sender != address(0), "No active bonus for this sender.");
        require(!info.fundsWithdrawn, "The bonus has already been paid out.");
        require(info.postDeadlineCheck, "Post deadline check not performed.");
        require(!info.meetSalesCondition, "The sales conditions are met for Receiver.");

        info.fundsWithdrawn = true;

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
        require(!info.fundsWithdrawn, "The bonus has already been paid out.");
        require(info.meetSalesCondition, "Sales condition isn't met");

        info.fundsWithdrawn = true;

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
        bool meetSalesCondition,
        bool postDeadlineCheck
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
