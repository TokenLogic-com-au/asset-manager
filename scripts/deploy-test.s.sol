// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {ArbitrumStrategyManager} from "src/arbitrum-foundation/ArbitrumStrategyManager.sol";

contract DesployTestScript is Script {
    ArbitrumStrategyManager public manager;
    // https://arbiscan.io/address/0x7166d92B5164884b49111703fB14f1aEEF933089
    // https://app.safe.global/home?safe=arb1:0x7166d92B5164884b49111703fB14f1aEEF933089
    address public constant TREASURY = 0x7166d92B5164884b49111703fB14f1aEEF933089;
    address public constant CONFIGURATOR = 0x7166d92B5164884b49111703fB14f1aEEF933089;
    address public constant ADMIN = 0x7166d92B5164884b49111703fB14f1aEEF933089;

    // https://arbiscan.io/address/0xf5a216fcca274eb1b71dcd4dca5e9c3ab4870a79
    address public constant HYPERNATIVE = 0xf5a216fcca274eb1b71dcd4dca5e9c3ab4870a79;

    address public constant AAVE_V3_POOL =
        0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant MERKL_DISTRIBUTOR =
        0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    function run() public {
        vm.startBroadcast();

        manager = new ArbitrumStrategyManager(
            ADMIN,
            AAVE_V3_POOL,
            TREASURY,
            MERKL_DISTRIBUTOR,
            HYPERNATIVE
        );

        vm.stopBroadcast();
    }
}
