// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "openzeppelin/access/AccessControl.sol";

import {IArbitrumStrategyManager} from "src/arbitrum-foundation/interfaces/IArbitrumStrategyManager.sol";
import {IMerkl} from "src/arbitrum-foundation/interfaces/IMerkl.sol";
import {IIncentivesController} from "src/arbitrum-foundation/interfaces/IIncentivesController.sol";
import {IPool} from "src/arbitrum-foundation/interfaces/IPool.sol";

contract ArbitrumStrategyManager is IArbitrumStrategyManager, AccessControl {
    using SafeERC20 for IERC20;

    /// @notice Returns the identifier of the Configurator Role
    /// @return The bytes32 id of the Configurator role
    bytes32 public constant CONFIGURATOR_ROLE = keccak256("CONFIGURATOR");

    /// @notice Returns the identifier of the Emergency Action Role
    /// @return The bytes32 id of the Emergency Action role
    bytes32 public constant EMERGENCY_ACTION_ROLE =
        keccak256("EMERGENCY_ACTION");

    /// @dev Maximum allowed basis points (100%)
    uint256 public constant MAX_BPS = 10_000;

    /// @dev Address of wstETH on Arbitrum
    address public constant WST_ETH =
        0x5979D7b546E38E414F7E9822514be443A4800529;

    /// @dev Address of the V3 wstETH aToken on Arbitrum
    address public constant WST_ETH_A_TOKEN =
        0x513c7E3a9c69cA3e22550eF58AC1C0088e918FFf;

    /// @dev Address of the Aave V3 Incentives Controller
    address internal constant AAVE_INCENTIVES_CONTROLLER =
        0x929EC64c34a17401F460460D4B9390518E5B473e;

    /// @dev Address of the Arbitrum Foundation treasury
    address public immutable _arbFoundation;

    /// @dev Address of the Aave V3 Pool
    address public _aaveV3Pool;

    /// @dev Address of the Merkl contract to claim rewards from
    address public _merkl;

    /// @dev Address of the Hypernative address allowed to call this contract
    address public _hypernative;

    /// @dev Maximum percentage of pool position can have (in bps)
    uint256 public _maxPositionThreshold = 3000;

    /// @dev Buffer used when scaling down a position to not be close to threshold
    uint256 public _bpsBuffer = 500;

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
    function claimAaveRewards() external {
        address[] memory assets = new address[](1);
        assets[0] = WST_ETH_A_TOKEN;
        IIncentivesController(AAVE_INCENTIVES_CONTROLLER).claimAllRewards(
            assets,
            _arbFoundation
        );

        emit ClaimedAaveRewards();
    }

    /// @inheritdoc IArbitrumStrategyManager
    function depositIntoAaveV3(
        uint256 amount
    ) external onlyRole(CONFIGURATOR_ROLE) {
        require(amount > 0, InvalidZeroAmount());

        (
            ,
            uint256 availableLiquidity,
            uint256 suppliedAmount
        ) = _getPositionData();

        uint256 positionPctAfterDeposit = ((suppliedAmount + amount) *
            MAX_BPS) / (availableLiquidity + amount);

        require(
            positionPctAfterDeposit < _maxPositionThreshold,
            DepositTooBig()
        );

        IERC20(WST_ETH).forceApprove(_aaveV3Pool, amount);
        IPool(_aaveV3Pool).supply(WST_ETH, amount, address(this), 0);

        emit DepositIntoAaveV3(amount);
    }

    /// @inheritdoc IArbitrumStrategyManager
    function withdrawFromAaveV3(
        uint256 amount
    ) external onlyRole(CONFIGURATOR_ROLE) {
        require(amount > 0, InvalidZeroAmount());

        IPool(_aaveV3Pool).withdraw(WST_ETH, amount, address(this));

        emit WithdrawFromAaveV3(amount);
    }

    /// @inheritdoc IArbitrumStrategyManager
    function withdrawAll() external onlyRole(EMERGENCY_ACTION_ROLE) {
        uint256 amount = IPool(_aaveV3Pool).withdraw(
            WST_ETH,
            type(uint256).max,
            address(this)
        );

        emit WithdrawFromAaveV3(amount);
    }

    /// @inheritdoc IArbitrumStrategyManager
    function scaleDown() external onlyRole(EMERGENCY_ACTION_ROLE) {
        _scaleDown();
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
        require(newThreshold > 0, InvalidZeroAmount());
        require(newThreshold < MAX_BPS, InvalidThreshold());

        uint256 old = _maxPositionThreshold;
        _maxPositionThreshold = newThreshold;

        _scaleDown();

        emit MaxPositionThresholdUpdated(old, newThreshold);
    }

    /// @inheritdoc IArbitrumStrategyManager
    function updateBpsBuffer(
        uint256 newBpsBuffer
    ) external onlyRole(CONFIGURATOR_ROLE) {
        require(newBpsBuffer > 0, InvalidZeroAmount());

        uint256 old = _bpsBuffer;
        _bpsBuffer = newBpsBuffer;

        emit BpsBufferUpdated(old, newBpsBuffer);
    }

    /// @inheritdoc IArbitrumStrategyManager
    function updateHypernative(
        address hypernative
    ) external onlyRole(CONFIGURATOR_ROLE) {
        require(hypernative != address(0), InvalidZeroAddress());

        address old = _hypernative;
        _hypernative = hypernative;

        _revokeRole(EMERGENCY_ACTION_ROLE, old);
        _grantRole(EMERGENCY_ACTION_ROLE, hypernative);

        emit HypernativeUpdated(old, hypernative);
    }

    /// @inheritdoc IArbitrumStrategyManager
    function updatePool(
        address newPoolAddress
    ) external onlyRole(CONFIGURATOR_ROLE) {
        require(newPoolAddress != address(0), InvalidZeroAddress());

        address old = _aaveV3Pool;
        _aaveV3Pool = newPoolAddress;

        emit PoolAddressUpdated(old, newPoolAddress);
    }

    /// @inheritdoc IArbitrumStrategyManager
    function updateMerkl(address merkl) external onlyRole(CONFIGURATOR_ROLE) {
        require(merkl != address(0), InvalidZeroAddress());

        address old = _merkl;
        _merkl = merkl;

        emit MerklUpdated(old, merkl);
    }

    /// @inheritdoc IArbitrumStrategyManager
    function getPositionData()
        external
        view
        returns (uint256, uint256, uint256)
    {
        return _getPositionData();
    }

    /// @dev Internal function to return position data
    /// @return Position size in percentage (in bps)
    /// @return Available liquidity in pool
    function _getPositionData()
        internal
        view
        returns (uint256, uint256, uint256)
    {
        uint256 suppliedAmount = IERC20(WST_ETH_A_TOKEN).balanceOf(
            address(this)
        );
        uint256 availableLiquidity = IPool(_aaveV3Pool)
            .getVirtualUnderlyingBalance(WST_ETH);

        return (
            (suppliedAmount * MAX_BPS) / availableLiquidity,
            availableLiquidity,
            suppliedAmount
        );
    }

    /// @dev Internal function to scale down position
    function _scaleDown() internal {
        (
            uint256 positionPct,
            uint256 availableLiquidity,
            uint256 suppliedAmount
        ) = _getPositionData();

        if (positionPct >= _maxPositionThreshold) {
            uint256 bpsToReduce = positionPct +
                _bpsBuffer -
                _maxPositionThreshold;
            uint256 excessAmount = (availableLiquidity * bpsToReduce) / MAX_BPS;

            /// This can happen if positionPct and _maxPositionThreshold
            /// have lower values compared to _bpsBuffer
            /// for example: if positionPct is 2 bps and _maxPositionThreshold is 1 bps
            /// due to _bpsBuffer being 500 bps, the amount needed to be withdrawn
            /// (excessAmount) will be bigger than current position.
            /// aave only allows to have a withdraw amount value above
            /// the current position amount, if type(uint256).max is used
            if (excessAmount > suppliedAmount) {
                excessAmount = suppliedAmount;
            }

            IPool(_aaveV3Pool).withdraw(WST_ETH, excessAmount, address(this));

            emit WithdrawFromAaveV3(excessAmount);
        }
    }
}
