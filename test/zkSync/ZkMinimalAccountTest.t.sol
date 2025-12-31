// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "../../src/zksync/ZkMinimalAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Transaction} from "foundry-era-contracts/libraries/MemoryTransactionHelper.sol";
import {MemoryTransactionHelper} from "foundry-era-contracts/libraries/MemoryTransactionHelper.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "foundry-era-contracts/Constants.sol";
import {ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "foundry-era-contracts/interfaces/IAccount.sol";

contract ZkMinimalAccountTest is Test {
    ZkMinimalAccount zkMinimalAccount;
    ERC20Mock usdc;

    uint256 constant AMOUNT = 1e18;
    address constant ANVIL_DEFAULT_ACCOUNT =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() public {
        zkMinimalAccount = new ZkMinimalAccount();
        zkMinimalAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
        usdc = new ERC20Mock();
        vm.deal(address(zkMinimalAccount), AMOUNT);
    }

    function testZkOwnerCanExecuteCommands() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(zkMinimalAccount),
            AMOUNT
        );

        Transaction memory txData = _createUnsginedTransaction(
            address(zkMinimalAccount),
            113,
            dest,
            value,
            data
        );
        // Act
        vm.prank(zkMinimalAccount.owner());
        zkMinimalAccount.executeTransaction(bytes32(0), bytes32(0), txData);
        // Assert
        assertEq(usdc.balanceOf(address(zkMinimalAccount)), AMOUNT);
        // If no revert, the test passes
    }

    // You'll also need --system-mode=true to run this test
    function testZkValidateTransaction() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(zkMinimalAccount),
            AMOUNT
        );
        Transaction memory transaction = _createUnsginedTransaction(
            zkMinimalAccount.owner(),
            113,
            dest,
            value,
            functionData
        );
        transaction = _signTransaction(transaction);

        // Act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = zkMinimalAccount.validateTransaction(
            bytes32(0),
            bytes32(0),
            transaction
        );

        // Assert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    //////////////////////////////////////////
    // Helper Functions
    //////////////////////////////////////////
    function _signTransaction(
        Transaction memory transaction
    ) internal view returns (Transaction memory) {
        bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(
            transaction
        );
        // bytes32 digest = unsignedTransactionHash.toEthSignedMessageHash();
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, unsignedTransactionHash);
        Transaction memory signedTransaction = transaction;
        signedTransaction.signature = abi.encodePacked(r, s, v);
        return signedTransaction;
    }

    function _createUnsginedTransaction(
        address from,
        uint8 transactionType,
        address to,
        uint256 value,
        bytes memory data
    ) internal view returns (Transaction memory) {
        // Fetch the nonce for the 'minimalAccount' (our smart contract account)
        // Note: vm.getNonce is a Foundry cheatcode. In a real zkSync environment,
        // you'd query the NonceHolder system contract.
        uint256 nonce = vm.getNonce(address(zkMinimalAccount));

        // Initialize an empty array for factory dependencies
        bytes32[] memory factoryDeps = new bytes32[](0);

        return
            Transaction({
                txType: transactionType, // e.g., 113 for zkSync AA
                from: uint256(uint160(from)), // Cast 'from' address to uint256
                to: uint256(uint160(to)), // Cast 'to' address to uint256
                gasLimit: 16777216, // Placeholder value (adjust as needed)
                gasPerPubdataByteLimit: 16777216, // Placeholder value
                maxFeePerGas: 16777216, // Placeholder value
                maxPriorityFeePerGas: 16777216, // Placeholder value
                paymaster: 0, // No paymaster for this example
                nonce: nonce, // Use the fetched nonce
                value: value, // Value to be transferred
                reserved: [uint256(0), uint256(0), uint256(0), uint256(0)], // Default empty
                data: data, // Transaction calldata
                signature: hex"", // Empty signature for an unsigned transaction
                factoryDeps: factoryDeps, // Empty factory dependencies
                paymasterInput: hex"", // No paymaster input
                reservedDynamic: hex"" // Empty reserved dynamic field
            });
    }
}
