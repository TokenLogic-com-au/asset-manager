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
    /// @return The bytes32 id of the Configurator role
    bytes32 public constant CONFIGURATOR_ROLE = "CONFIGURATOR";

    /// @notice Returns the identifier of the Emergency Action Role
    /// @return The bytes32 id of the Emergency Action role
    bytes32 public constant EMERGENCY_ACTION_ROLE = "EMERGENCY_ACTION";

    /// @dev Maximum allowed basis points (100%)
    uint256 internal constant MAX_BPS = 10_000;

    /// @dev Address of the Aave V3 Pool
    address internal immutable _aaveV3Pool;

    /// @dev Address of the Arbitrum Foundation treasury
    address public _arbFoundation;

    /// @dev Address of the Merkl contract to claim rewards from
    address public _merkl;

    /// @dev Address of the Hypernative address allowed to call this contract
    address public _hypernative;

    /// @dev Maximum percentage of pool position can have (in bps)
    uint256 public _maxPositionThreshold = 3000;

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
        require(initialAdmin != address(0), InvalidZeroAddress());
        require(aaveV3Pool != address(0), InvalidZeroAddress());
        require(arbFoundation != address(0), InvalidZeroAddress());
        require(merkl != address(0), InvalidZeroAddress());
        require(hypernative != address(0), InvalidZeroAddress());

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(CONFIGURATOR_ROLE, initialAdmin);
        _grantRole(EMERGENCY_ACTION_ROLE, initialAdmin);
        _grantRole(EMERGENCY_ACTION_ROLE, hypernative);

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
    function scaleDown(
        address underlying
    ) external onlyRole(EMERGENCY_ACTION_ROLE) {
        IPool.ReserveDataLegacy memory data = IPool(_aaveV3Pool).getReserveData(
            underlying
        );

        uint256 suppliedAmount = IERC20(data.aTokenAddress).balanceOf(
            address(this)
        );

        uint256 totalSupply = IERC20(data.aTokenAddress).totalSupply();
        uint256 totalVariableDebt = IERC20(data.variableDebtTokenAddress)
            .totalSupply();
        uint256 availableLiquidity = totalSupply - totalVariableDebt;

        uint256 thresholdLiquidity = (availableLiquidity *
            _maxPositionThreshold) / MAX_BPS;

        if (suppliedAmount > thresholdLiquidity) {
            uint256 excessAmount = suppliedAmount - thresholdLiquidity;

            IPool(_aaveV3Pool).withdraw(
                underlying,
                excessAmount,
                address(this)
            );
        }
    }

    /// @inheritdoc IArbitrumStrategyManager
    function emergencyTokenTransfer(
        address token,
        uint256 amount
    ) external onlyRole(CONFIGURATOR_ROLE) {
        IERC20(token).safeTransfer(_arbFoundation, amount);

        emit ERC20Rescued(token, _arbFoundation, amount);
    }

    /// @inheritdoc IArbitrumStrategyManager
    function updateMaxPositionThreshold(
        uint256 newThreshold
    ) external onlyRole(CONFIGURATOR_ROLE) {
        if (newThreshold > MAX_BPS) revert InvalidThreshold();

        uint256 old = _maxPositionThreshold;
        _maxPositionThreshold = newThreshold;

        emit MaxPositionThresholdUpdated(old, newThreshold);
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

    /// @inheritdoc IArbitrumStrategyManager
    function updateMerkl(address merkl) external onlyRole(CONFIGURATOR_ROLE) {
        require(merkl != address(0), InvalidZeroAddress());

        address old = _merkl;
        _merkl = merkl;

        emit MerklUpdated(old, merkl);
    }
}
