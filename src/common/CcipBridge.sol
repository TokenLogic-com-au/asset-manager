// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

import {ICcipBridge} from "src/common/ICcipBridge.sol";

contract CcipBridge is ICcipBridge, Ownable {
    using SafeERC20 for IERC20;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function bridge() external {}
}
