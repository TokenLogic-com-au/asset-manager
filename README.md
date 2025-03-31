## Arbitrum <> Aave wstETH Position Manager

The ArbitrumStrategyManager is a smart contract developed in order to better manage the Arbitrum Foundation's holdings of wstETH in order to generate yield.
The contract is designed for maximum simplicity and security, with very limited functionality to deposit and withdraw from Aave, as well as claiming rewards on behalf of Arbitrum Foundation, and transferring funds back to Arbitrum as well.

The contract leverages Hypernative in order to automatically scale down of positions or entirely withdraw from Aave. The contract is also monitored via the Hypernative platform, along with other general market metrics in order to ensure the safety of funds.

### Smart Contract Specs

The contract has an automated function in order to scale down the position deposited into Aave. The main idea is that the Aave pool always contains sufficient liquidity for the contract to withdraw all of the position in one transaction. If the automated monitoring sees that the position is greater than a certain percentage threshold of the available liquidity, it will downsize the position to below this threshold withi a certain buffer.

#### Contract Variables

1. Constants

`bytes32 public constant CONFIGURATOR_ROLE` is the role that can be granted to an address that can deposit/withdraw into Aave V3.
`bytes32 public constant EMERGENCY_ACTION_ROLE` is the role that can be granted to an address in order to perform emergency actions.
`uint256 public constant MAX_BPS`. Maximum basis points (10,000, which is 100%).
`uint256 public constant BPS_BUFFER`. Buffer used to determine maximum position size when scaling down of a position.
`address public constant WST_ETH`. Address of wstETH on Arbitrum One.
`address public constant WST_ETH_A_TOKEN`. Address of aArbWstETH on Arbitrum One.

2. Immutables

`address internal immutable _aaveV3Pool`. Address of the Aave V3 pool on Arbitrum One.
`address public immutable _arbFoundation`. Address of Arbitrum Foundation Treasury where tokens can only be withdrawn to out of this contract.

3. Mutables

`address public _merkl`. Address of the Merkl contract to claim rewards.
`address public _hypernative`. Address of new address that can perform emergency actions on this contract.
`uint256 public _maxPositionThreshold`. Maximum position threshold in terms of liquidity on Aave V3 pool.

#### Functionality

```
function claimRewards(
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external
```

This function is permissionless and is used in order to claim rewards from Merkl to be deposited into this contract.

```
function depositIntoAaveV3(
        uint256 amount
    ) external onlyRole(CONFIGURATOR_ROLE)
```

Function used to deposit a specified amount into Aave V3. Only an address with the CONFIGURATOR_ROLE can call this function.

```
function withdrawFromAaveV3(
        uint256 amount
    ) external onlyRole(CONFIGURATOR_ROLE)
```

Function used to withdraw a specified amount from Aave V3. Only an address with the CONFIGURATOR_ROLE can call this function.

`function withdrawAll() external onlyRole(EMERGENCY_ACTION_ROLE)`

Emergency function used to withdraw all funds from Aave V3. Only an address with the EMERGENCY_ACTION_ROLE can call this function.

`function scaleDown() external onlyRole(EMERGENCY_ACTION_ROLE)`

Function used to scale down position held in Aave V3 to have enough pool liquidity to withdraw full position. Only an address with the EMERGENCY_ACTION_ROLE can call this function.

```
function emergencyTokenTransfer(
        address token,
        uint256 amount
    ) external onlyRole(CONFIGURATOR_ROLE)
```

Function used to withdraw ERC20 tokens from this contract. Only an address with the CONFIGURATOR_ROLE can call this function.

```
function updateMaxPositionThreshold(
        uint256 newThreshold
    ) external onlyRole(CONFIGURATOR_ROLE)
```

Function used to update the maximum percentage a wstETH position can be of the total available liquidity in the Aave V3 pool. Only an address with the CONFIGURATOR_ROLE can call this function.

```
function updateHypernative(
        address hypernative
    ) external onlyRole(CONFIGURATOR_ROLE)
```

Function used to update the Hypernative address that has the EMERGENCY_ACTION_ROLE/the address that can call emergency functions. Only an address with the CONFIGURATOR_ROLE can call this function.

`function updateMerkl(address merkl) external onlyRole(CONFIGURATOR_ROLE)`

Function used to update the Merkl contract address to claim rewards from. Only an address with the CONFIGURATOR_ROLE can call this function.

`function getPositionData() external view returns (uint256, uint256)`

View function used to get the current position's size as a percentage of available liquidity, and the current available liquidity.
