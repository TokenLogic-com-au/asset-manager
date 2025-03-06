// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "openzeppelin/access/AccessControl.sol";

import {IArbitrumStrategyManager} from "src/arbitrum-foundation/interfaces/IArbitrumStrategyManager.sol";
import {IMerkl} from "src/arbitrum-foundation/interfaces/IMerkl.sol";
import {IPool} from "src/arbitrum-foundation/interfaces/IPool.sol";

contract ArbitrumStrategyManager is IArbitrumStrategyManager, AccessControl {
    using SafeERC20 for IERC20;

    /// @notice Returns the identifier of the Configurator Role
    /// @return The bytes32 id hash of the Configurator role
    bytes32 public constant CONFIGURATOR_ROLE = "CONFIGURATOR";

    /// @notice Returns the identifier of the Emergency Action Role
    /// @return The bytes32 id hash of the Emergency Action role
    bytes32 public constant EMERGENCY_ACTION_ROLE = "EMERGENCY_ACTION";

    /// @dev Address of the Aave V3 Pool
    address internal immutable _aaveV3Pool;

    /// @dev Address of the Arbitrum Foundation treasury
    address public _arbFoundation;

    /// @dev Address of the Merkl contract to claim rewards from
    address public _merkl;

    /// @dev Address of the Hypernative address allowed to call this contract
    address public _hypernative;

    /// @param initialAdmin The address of the initial admin of the contract
    /// @param aaveV3Pool The address of the Aave V3 Pool
    /// @param arbFoundation The address of the Arbitrum Foundation treasury
    /// @param merkl The address of the Merkl distributor contract
    /// @param hypernative The address of the emergency Hypernative caller
    constructor(
        address initialAdmin,
        address aaveV3Pool,
        address arbFoundation,
        address merkl,
        address hypernative
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(CONFIGURATOR_ROLE, initialAdmin);
        _grantRole(EMERGENCY_ACTION_ROLE, initialAdmin);
        _grantRole(EMERGENCY_ACTION_ROLE, hypernative);

        require(aaveV3Pool != address(0), InvalidZeroAddress());
        require(arbFoundation != address(0), InvalidZeroAddress());
        require(merkl != address(0), InvalidZeroAddress());
        require(hypernative != address(0), InvalidZeroAddress());

        _aaveV3Pool = aaveV3Pool;
        _arbFoundation = arbFoundation;
        _merkl = merkl;
        _hypernative = hypernative;
    }

    /// @inheritdoc IArbitrumStrategyManager
    function claimRewards(
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external {
        address[] memory users = new address[](1);
        users[0] = address(this);
        IMerkl(_merkl).claim(users, tokens, amounts, proofs);
        emit ClaimedMerklRewards();
    }

    /// @inheritdoc IArbitrumStrategyManager
    function depositIntoAaveV3(
        address underlying,
        uint256 amount
    ) external onlyRole(CONFIGURATOR_ROLE) {
        if (amount == 0) revert InvalidZeroAmount();

        IERC20(underlying).forceApprove(_aaveV3Pool, amount);
        IPool(_aaveV3Pool).supply(underlying, amount, address(this), 0);

        emit DepositIntoAaveV3(underlying, amount);
    }

    /// @inheritdoc IArbitrumStrategyManager
    function withdrawFromAaveV3(
        address underlying,
        uint256 amount
    ) external onlyRole(EMERGENCY_ACTION_ROLE) {
        if (amount == 0) revert InvalidZeroAmount();

        IPool(_aaveV3Pool).withdraw(underlying, amount, address(this));

        emit WithdrawFromAaveV3(underlying, amount);
    }

    /// @inheritdoc IArbitrumStrategyManager
    function swap(
        address from,
        address to,
        uint256 amount,
        uint256 minAmountOut
    ) external {
        require(false, "NOT IMPLEMENTED");
    }

    /// @inheritdoc IArbitrumStrategyManager
    function emergencyTokenTransfer(
        address token,
        address receiver,
        uint256 amount
    ) external onlyRole(CONFIGURATOR_ROLE) {
        if (receiver == address(0)) revert InvalidZeroAddress();

        IERC20(token).safeTransfer(receiver, amount);

        emit ERC20Rescued(token, receiver, amount);
    }

    /// @inheritdoc IArbitrumStrategyManager
    function updateHypernative(
        address hypernative
    ) external onlyRole(CONFIGURATOR_ROLE) {
        if (hypernative == address(0)) revert InvalidZeroAddress();

        address old = _hypernative;
        _hypernative = hypernative;

        _revokeRole(EMERGENCY_ACTION_ROLE, old);
        _grantRole(EMERGENCY_ACTION_ROLE, hypernative);

        emit HypernativeUpdated(old, hypernative);
    }

    function updateMerkl(address merkl) external onlyRole(CONFIGURATOR_ROLE) {
        require(merkl != address(0), InvalidZeroAddress());

        address old = _merkl;
        _merkl = merkl;

        emit MerklUpdated(old, merkl);
    }
}
