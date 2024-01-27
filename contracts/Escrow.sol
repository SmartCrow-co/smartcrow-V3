// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract Escrow is Ownable {

    using Address for address payable;

    mapping(address => mapping(address => mapping(string => uint256))) private _balances;

    constructor()Ownable(msg.sender) {}

    function depositsOf(address sender, address receiver, string memory propertyAddress) public view returns (uint256) {
        return _balances[sender][receiver][propertyAddress];
    }


    function deposit(address sender, address receiver, string memory propertyAddress) public payable virtual onlyOwner {
        uint256 amount = msg.value;
        _balances[sender][receiver][propertyAddress] += amount;
    }

    function withdraw(address payable payee,address sender, address receiver, string memory propertyAddress) public virtual onlyOwner {
        uint256 payment = _balances[sender][receiver][propertyAddress];

        _balances[sender][receiver][propertyAddress] = 0;

        payee.sendValue(payment);
    }
}