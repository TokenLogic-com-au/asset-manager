// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "openzeppelin/access/AccessControl.sol";
import {CCIPReceiver, IAny2EVMMessageReceiver, IERC165} from "chainlink/contracts-ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "chainlink/contracts-ccip/interfaces/IRouterClient.sol";
import {Client} from "chainlink/contracts-ccip/libraries/Client.sol";

import {ICcipBridge} from "src/common/ICcipBridge.sol";

contract CcipBridge is ICcipBridge, AccessControl {
    using SafeERC20 for IERC20;

    /// @inheritdoc IAaveCcipGhoBridge
    address public immutable ROUTER;

    /// @inheritdoc IAaveCcipGhoBridge
    mapping(uint64 selector => address bridge) public bridges;

    /// @dev Saves invalid message
    mapping(bytes32 messageId => Client.EVMTokenAmount[] message)
        private invalidTokenTransfers;

    /// @dev Saves state of invalid message.
    mapping(bytes32 messageId => bool failed) public isInvalidMessage;

    /// @param router The address of the Chainlink CCIP router
    constructor(address initialOwner, address router) {
        ROUTER = router;
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
    }

    /// @inheritdoc IAaveCcipGhoBridge
    function bridge(
        uint64 destinationChainSelector,
        uint256 amount,
        uint256 gasLimit,
        address feeToken
    ) external payable onlyRole(BRIDGER_ROLE) returns (bytes32 messageId) {
        _checkDestination(destinationChainSelector);

        Client.EVM2AnyMessage memory message = _buildCCIPMessage(
            destinationChainSelector,
            amount,
            gasLimit,
            feeToken
        );

        uint256 fee = IRouterClient(ROUTER).getFee(
            destinationChainSelector,
            message
        );

        uint256 inBalance = IERC20(GHO).balanceOf(address(this));
        uint256 totalGhoAmount = amount;

        if (feeToken == address(0)) {
            if (msg.value < fee) revert InsufficientNativeFee();
        } else if (feeToken == GHO) {
            totalGhoAmount += fee;
        } else {
            revert InvalidFeeToken();
        }

        if (inBalance < totalGhoAmount) {
            IERC20(GHO).transferFrom(
                msg.sender,
                address(this),
                totalGhoAmount - inBalance
            );
        }
        IERC20(GHO).approve(ROUTER, totalGhoAmount);

        messageId = IRouterClient(ROUTER).ccipSend{
            value: feeToken == address(0) ? fee : 0
        }(destinationChainSelector, message);

        if (feeToken == address(0)) {
            if (msg.value > fee) {
                payable(msg.sender).call{value: msg.value - fee}("");
            }
        } else {
            payable(msg.sender).call{value: msg.value}("");
        }

        emit TransferIssued(
            messageId,
            destinationChainSelector,
            msg.sender,
            amount
        );
    }

    /// @inheritdoc IAaveCcipGhoBridge
    function quoteBridge(
        uint64 destinationChainSelector,
        uint256 amount,
        uint256 gasLimit,
        address feeToken
    ) external view returns (uint256) {
        _checkDestination(destinationChainSelector);

        return
            IRouterClient(ROUTER).getFee(
                destinationChainSelector,
                _buildCCIPMessage(
                    destinationChainSelector,
                    amount,
                    gasLimit,
                    feeToken
                )
            );
    }

    /**
     * @dev Builds ccip message for token transfer
     * @param destinationChainSelector The selector of destination chain
     * @param amount The amount to transfer
     * @param gasLimit Gas limit on destination chain
     * @param feeToken The address of fee token
     * @return message EVM2EVMMessage to transfer token
     */
    function _buildCCIPMessage(
        uint64 destinationChainSelector,
        uint256 amount,
        uint256 gasLimit,
        address feeToken
    ) internal view returns (Client.EVM2AnyMessage memory message) {
        if (amount == 0) {
            revert InvalidTransferAmount();
        }
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: GHO, amount: amount});

        message = Client.EVM2AnyMessage({
            receiver: abi.encode(bridges[destinationChainSelector]),
            data: "",
            tokenAmounts: tokenAmounts,
            extraArgs: gasLimit == 0
                ? bytes("")
                : Client._argsToBytes(
                    Client.EVMExtraArgsV2({
                        gasLimit: gasLimit,
                        allowOutOfOrderExecution: false
                    })
                ),
            feeToken: feeToken
        });
    }

    /// @inheritdoc CCIPReceiver
    function ccipReceive(
        Client.Any2EVMMessage calldata message
    ) external override onlyRouter {
        try this.processMessage(message) {} catch {
            bytes32 messageId = message.messageId;

            Client.EVMTokenAmount[] memory tokenAmounts = message
                .destTokenAmounts;
            uint256 length = tokenAmounts.length;
            for (uint256 i = 0; i < length; ++i) {
                invalidTokenTransfers[messageId].push(tokenAmounts[i]);
            }
            isInvalidMessage[messageId] = true;

            emit ReceivedInvalidMessage(messageId);
        }
    }

    /// @dev wrap _ccipReceive as a external function
    function processMessage(
        Client.Any2EVMMessage calldata message
    ) external onlySelf {
        if (
            bridges[message.sourceChainSelector] !=
            abi.decode(message.sender, (address))
        ) {
            revert();
        }

        _ccipReceive(message);
    }

    /// @inheritdoc CCIPReceiver
    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        uint256 ghoAmount = message.destTokenAmounts[0].amount;

        IERC20(GHO).transfer(COLLECTOR, ghoAmount);

        emit TransferFinished(message.messageId, COLLECTOR, ghoAmount);
    }

    /// @inheritdoc IAaveCcipGhoBridge
    function getInvalidMessage(
        bytes32 messageId
    )
        external
        view
        checkInvalidMessage(messageId)
        returns (Client.EVMTokenAmount[] memory tokenAmounts)
    {
        uint256 length = invalidTokenTransfers[messageId].length;
        tokenAmounts = new Client.EVMTokenAmount[](length);

        for (uint256 i = 0; i < length; ++i) {
            tokenAmounts[i] = invalidTokenTransfers[messageId][i];
        }
    }

    /// @inheritdoc IAaveCcipGhoBridge
    function handleInvalidMessage(
        bytes32 messageId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) checkInvalidMessage(messageId) {
        isInvalidMessage[messageId] = false;

        Client.EVMTokenAmount[] memory tokenAmounts = invalidTokenTransfers[
            messageId
        ];
        uint256 length = tokenAmounts.length;
        for (uint256 i = 0; i < length; ++i) {
            IERC20(tokenAmounts[i].token).safeTransfer(
                COLLECTOR,
                tokenAmounts[i].amount
            );
        }

        emit HandledInvalidMessage(messageId);
    }

    /// @inheritdoc IAaveCcipGhoBridge
    function setDestinationBridge(
        uint64 _destinationChainSelector,
        address _bridge
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bridges[_destinationChainSelector] = _bridge;

        emit DestinationUpdated(_destinationChainSelector, _bridge);
    }
}
