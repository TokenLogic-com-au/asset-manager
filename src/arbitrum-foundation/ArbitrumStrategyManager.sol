// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "openzeppelin/access/AccessControl.sol";

import {IArbitrumStrategyManager} from "src/arbitrum-foundation/interfaces/IArbitrumStrategyManager.sol";
import {IPool} from "src/arbitrum-foundation/interfaces/IPool.sol";
import {IL2Gateway} from "src/arbitrum-foundation/interfaces/IL2Gateway.sol";

contract ArbitrumStrategyManager is IArbitrumStrategyManager, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant CONFIGURATOR = "CONFIGURATOR";
    bytes32 public constant EMERGENCY_ACTION = "EMERGENCY_ACTION";
    uint256 public constant ARBITRUM = 42161;

    address internal immutable _aaveV3Pool;
    address internal _arbFoundation;
    address internal _ccipBridge;
    address internal _mainnetContract;
    address internal _hypernative;

    constructor(
        address initialOwner,
        address aaveV3Pool,
        address arbFoundation
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _aaveV3Pool = aaveV3Pool;
        _arbFoundation = arbFoundation;
    }

    function claimRewards(address from) external {}

    function depositIntoAaveV3(
        address underlying,
        uint256 amount
    ) external onlyRole(CONFIGURATOR) {
        IPool(_aaveV3Pool).supply(underlying, amount, address(this), 0);

        emit DepositIntoAaveV3(underlying, amount);
    }

    function withdrawFromAaveV3(
        address underlying,
        uint256 amount
    ) external onlyRole(CONFIGURATOR) onlyRole(EMERGENCY_ACTION) {
        IPool(_aaveV3Pool).withdraw(underlying, amount, address(this));

        emit WithdrawFromAaveV3(underlying, amount);
    }

    function swap(
        address from,
        address to,
        uint256 amount,
        uint256 minAmountOut
    ) external {}

    function bridge(
        address token,
        address l1Token,
        address gateway,
        uint256 amount
    ) external {
        if (block.chainid != ARBITRUM) revert InvalidChain();

        IERC20(token).forceApprove(gateway, amount);

        IL2Gateway(gateway).outboundTransfer(
            l1Token,
            _mainnetContract,
            amount,
            ""
        );

        emit Bridge(token, amount);
    }

    function updateHypernative(
        address hypernative
    ) external onlyRole(CONFIGURATOR) {
        if (hypernative == address(0)) revert InvalidZeroAddress();

        address old = _hypernative;
        _hypernative = hypernative;

        emit HypernativeUpdated(old, hypernative);
    }
}
