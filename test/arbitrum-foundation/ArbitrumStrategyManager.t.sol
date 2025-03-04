// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {ArbitrumStrategyManager, IArbitrumStrategyManager} from "src/arbitrum-foundation/ArbitrumStrategyManager.sol";

/**
 * @dev Tests for ArbitrumStrategyManager contract
 * command: forge test --match-path tests/arbitrum-foundation/ArbitrumStrategyManager.t.sol -vvv
 */
contract ArbitrumStrategyManagerTest is Test {
    address public constant guardian = address(82);
    address public alice = address(43);
    ArbitrumStrategyManager public manager;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 21975495); // https://etherscan.io/block/21975495

        manager = new ArbitrumStrategyManager();

        vm.label(address(AaveV3Ethereum.COLLECTOR), "Collector");
        vm.label(alice, "Alice");
        vm.label(guardian, "Guardian");
        vm.label(address(manager), "ArbitrumStrategyManager");

        deal(
            AaveV3EthereumAssets.USDC_UNDERLYING,
            address(AaveV3Ethereum.COLLECTOR),
            1_000_000e6
        );
    }
}

contract ClaimRewardsTeset is ArbitrumStrategyManagerTest {}

contract DepositIntoAaveV3Test is ArbitrumStrategyManagerTest {
    function test_revertsIf_noRole() public {
        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector,
                alice
            )
        );
        steward.depositV3(
            address(AaveV3Ethereum.POOL),
            AaveV3EthereumAssets.USDC_UNDERLYING,
            1_000e6
        );
        vm.stopPrank();
    }

    function test_revertsIf_zeroAmount() public {
        vm.startPrank(guardian);

        vm.expectRevert(CollectorUtils.InvalidZeroAmount.selector);
        steward.depositV3(
            address(AaveV3Ethereum.POOL),
            AaveV3EthereumAssets.USDC_UNDERLYING,
            0
        );
        vm.stopPrank();
    }

    function test_success() public {
        uint256 balanceBefore = IERC20(AaveV3EthereumAssets.USDC_A_TOKEN)
            .balanceOf(address(AaveV3Ethereum.COLLECTOR));
        vm.startPrank(guardian);

        steward.depositV3(
            address(AaveV3Ethereum.POOL),
            AaveV3EthereumAssets.USDC_UNDERLYING,
            1_000e6
        );

        assertGt(
            IERC20(AaveV3EthereumAssets.USDC_A_TOKEN).balanceOf(
                address(AaveV3Ethereum.COLLECTOR)
            ),
            balanceBefore
        );
        vm.stopPrank();
    }
}

contract WithdrawFromAaveV3Test is ArbitrumStrategyManagerTest {}

contract BridgeTest is ArbitrumStrategyManagerTest {}

contract SwapTest is ArbitrumStrategyManagerTest {}

contract UpdateHypernativeTest is ArbitrumStrategyManagerTest {}
