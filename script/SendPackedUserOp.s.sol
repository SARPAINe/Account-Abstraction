// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;
import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() public {}

    function generateSignedUserOp(
        bytes memory callData,
        HelperConfig.NetworkConfig memory networkConfig
    ) public view returns (PackedUserOperation memory) {
        //1. Generate the unsigned data
        uint256 nonce = vm.getNonce(networkConfig.account);
        PackedUserOperation memory userOp = _generateUnsignedUserOp(
            callData,
            networkConfig.account,
            nonce
        );

        //2. Get the userOpHash
        bytes32 userOpHash = IEntryPoint(networkConfig.entryPoint)
            .getUserOpHash(userOp);

        bytes32 digest = userOpHash.toEthSignedMessageHash();

        //3. sign it
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            networkConfig.account,
            digest
        );
        userOp.signature = abi.encodePacked(r, s, v); // note the order
        return userOp;
    }

    function _generateUnsignedUserOp(
        bytes memory callData,
        address sender,
        uint256 nonce
    ) internal pure returns (PackedUserOperation memory) {
        // Example gas parameters (these may need tuning)
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit; // Often different in practice
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas; // Simplification for example

        // Pack accountGasLimits: (verificationGasLimit << 128) | callGasLimit
        bytes32 accountGasLimits = bytes32(
            (uint256(verificationGasLimit) << 128) | uint256(callGasLimit)
        );

        // Pack gasFees: (maxFeePerGas << 128) | maxPriorityFeePerGas
        bytes32 gasFees = bytes32(
            (uint256(maxFeePerGas) << 128) | uint256(maxPriorityFeePerGas)
        );

        return
            PackedUserOperation({
                sender: sender,
                nonce: nonce,
                initCode: hex"", // Empty for existing accounts
                callData: callData,
                accountGasLimits: accountGasLimits,
                preVerificationGas: verificationGasLimit, // Often related to verificationGasLimit
                gasFees: gasFees,
                paymasterAndData: hex"", // Empty if not using a paymaster
                signature: hex"" // Crucially, the signature is blank for an unsigned operation
            });
    }
}
