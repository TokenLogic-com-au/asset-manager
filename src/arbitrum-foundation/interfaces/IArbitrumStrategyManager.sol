// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IArbitrumStrategyManager {
    /// @dev Emitted when the rewards earned via Merkl are claimed by the contract
    event ClaimedMerklRewards();

    /// @dev Emitted when wstETH is deposited into the Aave V3 protocol
    /// @param amount The amount of tokens deposited
    event DepositIntoAaveV3(uint256 amount);

    /// @dev Emitted when an ERC20 token is rescued from the contract
    /// @param token The address of the rescued ERC20 token
    /// @param receiver The address receiving the rescued tokens
    /// @param amount The amount of tokens rescued
    event ERC20Rescued(address indexed token, address receiver, uint256 amount);

    /// @dev Emitted when the Merkl address is updated
    /// @param oldMerkl The previous Merkl address
    /// @param newMerkl The new Merkl address
    event MerklUpdated(address oldMerkl, address newMerkl);

    /// @dev Emitted when the maximum position threshold on Aave is updated
    /// @param oldThreshold The previous threshold (in bps)
    /// @param newThreshold The new threshold (in bps)
    event MaxPositionThresholdUpdated(
        uint256 oldThreshold,
        uint256 newThreshold
    );

    /// @dev Emitted when the Hypernative address is updated
    /// @param oldHypernative The previous Hypernative address
    /// @param newHypernative The new Hypernative address
    event HypernativeUpdated(address oldHypernative, address newHypernative);

    /// @dev Emitted when wstETH is withdrawn from the Aave V3 protocol
    /// @param amount The amount of tokens withdrawn
    event WithdrawFromAaveV3(uint256 amount);

    /// @dev Threshold must be lower than 100% (in bps)
    error InvalidThreshold();

    /// @dev Amount must be greater than zero
    error InvalidZeroAmount();

    /// @dev Address cannot be the zero-address
    error InvalidZeroAddress();

    /// @notice Claims rewards from Merkl system
    /// @param tokens Array with addresses of tokens to claim rewards for
    /// @param amounts Array with amounts of tokens to claim
    /// @param proofs Array with proofs needed to claim rewards
    function claimRewards(
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external;

    /// @notice Deposits underlying tokens into the Aave V3 protocol
    /// @param amount The amount of tokens to deposit
    function depositIntoAaveV3(uint256 amount) external;

    /// @notice Withdraws tokens from the Aave V3 protocol
    /// @param amount The amount of tokens to withdraw
    function withdrawFromAaveV3(uint256 amount) external;

    /// @notice Withdraws all tokens from the Aave V3 protocol
    function withdrawAll() external;

    /// @notice Withdraws from AaveV3 to ensure position is never greater than a set % of the pool
    function scaleDown() external;

    /// @notice Emergency function to transfer ERC20 tokens
    /// @param token The address of the ERC20 token to transfer
    /// @param amount The amount of tokens to transfer
    function emergencyTokenTransfer(address token, uint256 amount) external;

    /// @notice Updates the Hypernative address
    /// @param hypernative The new Hypernative address to set
    function updateHypernative(address hypernative) external;

    /// @notice Updates the maximum position threshold
    /// @param newThreshold The new maximum position threshold (in bps)
    function updateMaxPositionThreshold(uint256 newThreshold) external;

    /// @notice Updates the address of the Merkl contract to claim rewards from
    /// @param merkl The address of the new Merkl contract
    function updateMerkl(address merkl) external;

    /// @notice Returns the position percentage relative to the available liquidity in the pool (in bps)
    /// @return Position size in percentage (in bps)
    /// @return Available liquidity in pool
    /// @return Position size
    function getPositionData() external view returns (uint256, uint256, uint256);
}
