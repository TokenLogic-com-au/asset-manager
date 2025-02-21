// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {Ownable} from "openzeppelin/access/Ownable.sol";

contract WstEthHandler is Ownable {
    constructor(address initialOwner) Ownable(initialOwner) {}

    receive() external payable {}

    function deposit(uint256 amount) external {}

    function withdraw(uint256 amount) external {}

    function unwrap(uint256 amount) external {}
}
