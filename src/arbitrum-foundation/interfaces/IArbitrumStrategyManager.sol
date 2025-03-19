// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IArbitrumStrategyManager {
    /// @dev Emitted when the rewards earned via Merkl are claimed by the contract
    event ClaimedMerklRewards();

    /// @dev Emitted when tokens are deposited into the Aave V3 protocol
    /// @param token The address of the token being deposited
    /// @param amount The amount of tokens deposited
    event DepositIntoAaveV3(address token, uint256 amount);

    /// @dev Emitted when an ERC20 token is rescued from the contract
    /// @param token The address of the rescued ERC20 token
    /// @param receiver The address receiving the rescued tokens
    /// @param amount The amount of tokens rescued
    event ERC20Rescued(address indexed token, address receiver, uint256 amount);

    /// @dev Emitted when the Merkl address is updated
    /// @param oldMerkl The previous Merkl address
    /// @param newMerkl The new Merkl address
    event MerklUpdated(address oldMerkl, address newMerkl);

    /// @dev Emitted when the Hypernative address is updated
    /// @param oldHypernative The previous Hypernative address
    /// @param newHypernative The new Hypernative address
    event HypernativeUpdated(address oldHypernative, address newHypernative);

    /// @dev Emitted when tokens are withdrawn from the Aave V3 protocol
    /// @param token The address of the token being withdrawn
    /// @param amount The amount of tokens withdrawn
    event WithdrawFromAaveV3(address token, uint256 amount);

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
    /// @param underlying The address of the token to deposit
    /// @param amount The amount of tokens to deposit
    function depositIntoAaveV3(address underlying, uint256 amount) external;

    /// @notice Withdraws tokens from the Aave V3 protocol
    /// @param underlying The address of the token to withdraw
    /// @param amount The amount of tokens to withdraw
    function withdrawFromAaveV3(address underlying, uint256 amount) external;

    /// @notice Swaps one ERC20 token for another
    /// @param from The address of the token to swap from
    /// @param to The address of the token to swap to
    /// @param amount The amount of tokens to swap
    /// @param minAmountOut The minimum amount of output tokens expected
    function swap(
        address from,
        address to,
        uint256 amount,
        uint256 minAmountOut
    ) external;

    /// @notice Emergency function to transfer ERC20 tokens
    /// @param token The address of the ERC20 token to transfer
    /// @param amount The amount of tokens to transfer
    function emergencyTokenTransfer(address token, uint256 amount) external;

    /// @notice Updates the Hypernative address
    /// @param hypernative The new Hypernative address to set
    function updateHypernative(address hypernative) external;
}
