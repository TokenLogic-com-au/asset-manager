// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AccessControl, IAccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IPool} from "src/arbitrum-foundation/interfaces/IPool.sol";

import {ArbitrumStrategyManager, IArbitrumStrategyManager} from "src/arbitrum-foundation/ArbitrumStrategyManager.sol";

/**
 * @dev Tests for ArbitrumStrategyManager contract
 * command: forge test --match-path test/arbitrum-foundation/ArbitrumStrategyManager.t.sol -vvv
 */
contract ArbitrumStrategyManagerTest is Test {
    address public constant AAVE_V3_POOL =
        0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant WST_ETH =
        0x5979D7b546E38E414F7E9822514be443A4800529;
    address public constant WST_ETH_A_TOKEN =
        0x513c7E3a9c69cA3e22550eF58AC1C0088e918FFf;
    address public constant MERKL_DISTRIBUTOR =
        0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    address public constant arbitrumFoundationTreasury = address(100);
    address public constant hypernative = address(101);
    address public constant configurator = address(102);
    address public constant admin = address(104);

    ArbitrumStrategyManager public manager;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("arbitrum"), 321886638); // https://arbiscan.io/block/321886638

        manager = new ArbitrumStrategyManager(
            admin,
            AAVE_V3_POOL,
            arbitrumFoundationTreasury,
            MERKL_DISTRIBUTOR,
            hypernative
        );

        vm.label(admin, "Admin");
        vm.label(arbitrumFoundationTreasury, "ArbitrumFoundationTreasury");
        vm.label(configurator, "Configurator");
        vm.label(hypernative, "Hypernative");
        vm.label(address(manager), "ArbitrumStrategyManager");

        deal(WST_ETH, address(manager), 100_000 ether);

        // Assign roles
        vm.startPrank(admin);
        manager.grantRole(manager.CONFIGURATOR_ROLE(), configurator);
        vm.stopPrank();
    }
}

contract ConstructorTest is Test {
    address public constant AAVE_V3_POOL =
        0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant MERKL_DISTRIBUTOR =
        0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address public constant arbitrumFoundationTreasury = address(100);
    address public constant hypernative = address(101);
    address public constant admin = address(104);

    function test_revertsIf_initialAdminIsZeroAddress() public {
        vm.expectRevert(IArbitrumStrategyManager.InvalidZeroAddress.selector);
        new ArbitrumStrategyManager(
            address(0),
            AAVE_V3_POOL,
            arbitrumFoundationTreasury,
            MERKL_DISTRIBUTOR,
            hypernative
        );
    }

    function test_revertsIf_aaveV3PoolIsZeroAddress() public {
        vm.expectRevert(IArbitrumStrategyManager.InvalidZeroAddress.selector);
        new ArbitrumStrategyManager(
            admin,
            address(0),
            arbitrumFoundationTreasury,
            MERKL_DISTRIBUTOR,
            hypernative
        );
    }

    function test_revertsIf_arbFoundationIsZeroAddress() public {
        vm.expectRevert(IArbitrumStrategyManager.InvalidZeroAddress.selector);
        new ArbitrumStrategyManager(
            admin,
            AAVE_V3_POOL,
            address(0),
            MERKL_DISTRIBUTOR,
            hypernative
        );
    }

    function test_revertsIf_merklDistributorIsZeroAddress() public {
        vm.expectRevert(IArbitrumStrategyManager.InvalidZeroAddress.selector);
        new ArbitrumStrategyManager(
            admin,
            AAVE_V3_POOL,
            arbitrumFoundationTreasury,
            address(0),
            hypernative
        );
    }

    function test_revertsIf_hypernativeDistributorIsZeroAddress() public {
        vm.expectRevert(IArbitrumStrategyManager.InvalidZeroAddress.selector);
        new ArbitrumStrategyManager(
            admin,
            AAVE_V3_POOL,
            arbitrumFoundationTreasury,
            MERKL_DISTRIBUTOR,
            address(0)
        );
    }

    function test_successful() public {
        ArbitrumStrategyManager manager = new ArbitrumStrategyManager(
            admin,
            AAVE_V3_POOL,
            arbitrumFoundationTreasury,
            MERKL_DISTRIBUTOR,
            hypernative
        );

        assertEq(manager._arbFoundation(), arbitrumFoundationTreasury);
        assertEq(manager._merkl(), MERKL_DISTRIBUTOR);
        assertEq(manager._hypernative(), hypernative);

        assertTrue(
            AccessControl(manager).hasRole(manager.CONFIGURATOR_ROLE(), admin)
        );
        assertTrue(
            AccessControl(manager).hasRole(manager.DEFAULT_ADMIN_ROLE(), admin)
        );
        assertTrue(
            AccessControl(manager).hasRole(
                manager.EMERGENCY_ACTION_ROLE(),
                admin
            )
        );
        assertTrue(
            AccessControl(manager).hasRole(
                manager.EMERGENCY_ACTION_ROLE(),
                hypernative
            )
        );
    }
}

contract ClaimRewardsTest is ArbitrumStrategyManagerTest {
    error InvalidProof();

    function test_revertsIf_invalidProof() public {
        // Setup mock Merkl data (simplified)
        address[] memory tokens = new address[](1);
        tokens[0] = WST_ETH;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100 ether;
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](0); // Empty proof for simplicity

        vm.expectRevert(ClaimRewardsTest.InvalidProof.selector);
        manager.claimRewards(tokens, amounts, proofs);
    }
}

contract DepositIntoAaveV3Test is ArbitrumStrategyManagerTest {
    function test_revertsIf_noRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                manager.CONFIGURATOR_ROLE()
            )
        );
        manager.depositIntoAaveV3(1_000e6);
    }

    function test_revertsIf_zeroAmount() public {
        vm.startPrank(configurator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArbitrumStrategyManager.InvalidZeroAmount.selector
            )
        );
        manager.depositIntoAaveV3(0);
        vm.stopPrank();
    }

    function test_success() public {
        uint256 balanceBefore = IERC20(WST_ETH_A_TOKEN).balanceOf(
            address(manager)
        );
        uint256 amount = 1_000 ether;

        vm.startPrank(configurator);
        vm.expectEmit(true, true, true, true, address(manager));
        emit IArbitrumStrategyManager.DepositIntoAaveV3(amount);
        manager.depositIntoAaveV3(amount);

        assertGt(
            IERC20(WST_ETH_A_TOKEN).balanceOf(address(manager)),
            balanceBefore
        );
        vm.stopPrank();
    }
}

contract WithdrawFromAaveV3Test is ArbitrumStrategyManagerTest {
    function test_revertsIf_noRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                manager.CONFIGURATOR_ROLE()
            )
        );
        manager.withdrawFromAaveV3(1_000 ether);
    }

    function test_revertsIf_zeroAmount() public {
        vm.startPrank(configurator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArbitrumStrategyManager.InvalidZeroAmount.selector
            )
        );
        manager.withdrawFromAaveV3(0);
        vm.stopPrank();
    }

    function test_success() public {
        // First deposit to have something to withdraw
        vm.prank(configurator);
        manager.depositIntoAaveV3(1_000 ether);

        uint256 balanceBefore = IERC20(WST_ETH).balanceOf(address(manager));
        uint256 amount = 500 ether;

        vm.startPrank(configurator);
        vm.expectEmit(true, true, true, true, address(manager));
        emit IArbitrumStrategyManager.WithdrawFromAaveV3(amount);
        manager.withdrawFromAaveV3(amount);

        assertGt(IERC20(WST_ETH).balanceOf(address(manager)), balanceBefore);
        vm.stopPrank();
    }
}

contract WithdrawAllTest is ArbitrumStrategyManagerTest {
    function test_revertsIf_noRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                manager.EMERGENCY_ACTION_ROLE()
            )
        );
        manager.withdrawAll();
    }

    function test_successful() public {
        uint256 amount = 1_000 ether;

        assertEq(IERC20(WST_ETH_A_TOKEN).balanceOf(address(manager)), 0);
        // First deposit to have something to withdraw
        vm.prank(configurator);
        manager.depositIntoAaveV3(amount);

        assertEq(IERC20(WST_ETH_A_TOKEN).balanceOf(address(manager)), amount);

        vm.prank(hypernative);
        vm.expectEmit(true, true, true, true, address(manager));
        emit IArbitrumStrategyManager.WithdrawFromAaveV3(amount);
        manager.withdrawAll();

        assertEq(IERC20(WST_ETH_A_TOKEN).balanceOf(address(manager)), 0);
    }
}

contract ScaleDownTest is ArbitrumStrategyManagerTest {
    function test_revertsIf_noRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                manager.EMERGENCY_ACTION_ROLE()
            )
        );
        manager.scaleDown();
    }

    function test_minimum_deposit_successful() public {
        uint256 availableLiquidity = IPool(AAVE_V3_POOL)
            .getVirtualUnderlyingBalance(WST_ETH);
        uint256 maxBPS = manager.MAX_BPS();
        uint256 bufferBPS = manager.BPS_BUFFER();

        uint256 maxPositionThreshold = 1;
        
        /// MAX_BPS     - availableLiquidity
        /// MIN_POSITION_BPS - minThresholdAmount
        uint256 minThresholdAmount = availableLiquidity / maxBPS;
        vm.startPrank(configurator);
        manager.updateMaxPositionThreshold(maxPositionThreshold);
        manager.depositIntoAaveV3(4.3 ether);
        vm.stopPrank();

        (uint256 pct, uint256 newAvailableLiquidity, uint256 positionSize) = manager.getPositionData();

        uint256 bpsToReduce = pct + bufferBPS - maxPositionThreshold;
        uint256 excessAmount = (newAvailableLiquidity * bpsToReduce) / maxBPS;

        if (excessAmount > positionSize) {
            excessAmount = positionSize;
        }

        vm.expectEmit(true, true, true, true, address(manager));
        emit IArbitrumStrategyManager.WithdrawFromAaveV3(excessAmount);

        vm.prank(hypernative);
        manager.scaleDown();

        (pct, ,) = manager.getPositionData();
        assertLt(pct, manager._maxPositionThreshold());
    }

    function test_successful() public {
        vm.prank(configurator);
        manager.depositIntoAaveV3(20_000 ether);
        (uint256 pct, uint256 availableLiquidity,) = manager.getPositionData();

        // Position is now greater than maximum threshold, can scale down
        assertGt(pct, manager._maxPositionThreshold());

        uint256 bpsToReduce = (pct - manager._maxPositionThreshold()) +
            manager.BPS_BUFFER();
        uint256 excessAmount = (availableLiquidity * bpsToReduce) /
            manager.MAX_BPS();

        vm.expectEmit(true, true, true, true, address(manager));
        emit IArbitrumStrategyManager.WithdrawFromAaveV3(excessAmount);

        vm.prank(hypernative);
        manager.scaleDown();

        (pct, ,) = manager.getPositionData();
        assertLt(pct, manager._maxPositionThreshold());
    }
}

contract EmergencyTokenTransferTest is ArbitrumStrategyManagerTest {
    function test_revertsIf_noRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                manager.CONFIGURATOR_ROLE()
            )
        );
        manager.emergencyTokenTransfer(WST_ETH, 1_000 ether);
    }

    function test_success() public {
        uint256 amount = 1_000 ether;
        uint256 balanceBefore = IERC20(WST_ETH).balanceOf(
            manager._arbFoundation()
        );

        vm.startPrank(configurator);
        vm.expectEmit(true, true, true, true, address(manager));
        emit IArbitrumStrategyManager.ERC20Rescued(
            WST_ETH,
            manager._arbFoundation(),
            amount
        );
        manager.emergencyTokenTransfer(WST_ETH, amount);

        assertEq(
            IERC20(WST_ETH).balanceOf(manager._arbFoundation()),
            balanceBefore + amount
        );
        vm.stopPrank();
    }
}

contract UpdateMaxThresholdTest is ArbitrumStrategyManagerTest {
    function test_revertsIf_noRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                manager.CONFIGURATOR_ROLE()
            )
        );
        manager.updateMaxPositionThreshold(500);
    }

    function test_revertsIf_invalidThreshold() public {
        vm.startPrank(configurator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArbitrumStrategyManager.InvalidThreshold.selector
            )
        );
        manager.updateMaxPositionThreshold(10_001);
    }

    function test_successful() public {
        uint256 newThreshold = 2350;

        vm.startPrank(configurator);
        vm.expectEmit(true, true, true, true, address(manager));
        emit IArbitrumStrategyManager.MaxPositionThresholdUpdated(
            manager._maxPositionThreshold(),
            newThreshold
        );
        manager.updateMaxPositionThreshold(newThreshold);
        vm.stopPrank();
    }
}

contract UpdateHypernativeTest is ArbitrumStrategyManagerTest {
    function test_revertsIf_noRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                manager.CONFIGURATOR_ROLE()
            )
        );
        manager.updateHypernative(address(0x123));
    }

    function test_revertsIf_zeroAddress() public {
        vm.startPrank(configurator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArbitrumStrategyManager.InvalidZeroAddress.selector
            )
        );
        manager.updateHypernative(address(0));
        vm.stopPrank();
    }

    function test_success() public {
        address newHypernative = address(0x123);

        assertTrue(
            AccessControl(manager).hasRole(
                manager.EMERGENCY_ACTION_ROLE(),
                hypernative
            )
        );
        assertFalse(
            AccessControl(manager).hasRole(
                manager.EMERGENCY_ACTION_ROLE(),
                newHypernative
            )
        );

        vm.startPrank(configurator);
        vm.expectEmit(true, true, true, true, address(manager));
        emit IArbitrumStrategyManager.HypernativeUpdated(
            hypernative,
            newHypernative
        );
        manager.updateHypernative(newHypernative);
        vm.stopPrank();

        assertFalse(
            AccessControl(manager).hasRole(
                manager.EMERGENCY_ACTION_ROLE(),
                hypernative
            )
        );
        assertTrue(
            AccessControl(manager).hasRole(
                manager.EMERGENCY_ACTION_ROLE(),
                newHypernative
            )
        );
    }
}

contract UpdateMerklTest is ArbitrumStrategyManagerTest {
    function test_revertsIf_noRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                manager.CONFIGURATOR_ROLE()
            )
        );
        manager.updateMerkl(address(0x123));
    }

    function test_revertsIf_zeroAddress() public {
        vm.startPrank(configurator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArbitrumStrategyManager.InvalidZeroAddress.selector
            )
        );
        manager.updateMerkl(address(0));
    }

    function test_success() public {
        address newMerkl = address(0x456);
        vm.startPrank(configurator);
        vm.expectEmit(true, true, true, true, address(manager));
        emit IArbitrumStrategyManager.MerklUpdated(MERKL_DISTRIBUTOR, newMerkl);
        manager.updateMerkl(newMerkl);
    }
}

contract GetPositionPct is ArbitrumStrategyManagerTest {
    function test_success_noDeposit() public view {
        (uint256 pct, ,) = manager.getPositionData();
        assertEq(pct, 0);
    }

    function test_success_withBalance() public {
        // First deposit to have something to withdraw
        vm.prank(configurator);
        manager.depositIntoAaveV3(1_000 ether);

        (uint256 pct, ,) = manager.getPositionData();

        assertEq(pct, 274);
    }
}
