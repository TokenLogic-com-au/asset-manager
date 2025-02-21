// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {Ownable} from "openzeppelin/access/Ownable.sol";

contract ArbitrumStrategyManager is Ownable {
    address internal _ccipBridge;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function depositIntoAaveV3(address underlying, uint256 amount) external {}

    function withdrawFromAaveV3(address underlying, uint256 amount) external {}

    function claimRewards(address from) external {}

    function bridge(address token, uint256 amount) external {}

    function swap(
        address from,
        address to,
        uint256 amount,
        uint256 minAmountOut
    ) external {}

    function updateCcipBridge(address ccipBridge) external {}
}
