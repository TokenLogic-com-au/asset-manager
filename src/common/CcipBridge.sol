// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {Ownable} from "openzeppelin/access/Ownable.sol";

contract CcipBridge is Ownable {
    constructor(address initialOwner) Ownable(initialOwner) {}

    function bridge() external {}
}
