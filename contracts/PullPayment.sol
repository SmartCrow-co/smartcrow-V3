// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.20;
import {Escrow} from "./Escrow.sol";

contract PullPayment {
    Escrow private immutable _escrow;

    constructor() {
        _escrow = new Escrow();
    }

    function withdrawPayments(address payable payee,address sender, address receiver, string memory propertyAddress) internal virtual {
        _escrow.withdraw(payee, sender,  receiver, propertyAddress);
    }

    function payments(address sender, address receiver, string memory propertyAddress) public view returns (uint256) {
        return _escrow.depositsOf(sender,  receiver, propertyAddress );
    }

    function _asyncTransfer(address sender, address receiver, string memory propertyAddress, uint256 amount) internal virtual {
        _escrow.deposit{value: amount}(sender, receiver, propertyAddress);
    }
}