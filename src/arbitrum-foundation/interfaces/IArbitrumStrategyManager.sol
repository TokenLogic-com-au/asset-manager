// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

interface IArbitrumStrategyManager {
    event Bridge(address token, uint256 amount);
    event CcipBridgeUpdated(address oldBridge, address newBridge);
    event DepositIntoAaveV3(address token, uint256 amount);
    event HypernativeUpdated(address oldHypernative, address newHypernative);
    event WithdrawFromAaveV3(address token, uint256 amount);

    error InvalidChain();
    error InvalidZeroAddress();

    function claimRewards(address from) external;

    function depositIntoAaveV3(address underlying, uint256 amount) external;

    function withdrawFromAaveV3(address underlying, uint256 amount) external;

    function swap(
        address from,
        address to,
        uint256 amount,
        uint256 minAmountOut
    ) external;

    function bridge(
        address token,
        address l1Token,
        address gateway,
        uint256 amount
    ) external;

    function updateHypernative(address hypernative) external;
}
