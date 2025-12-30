// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAccount} from "account-abstraction/interfaces/IAccount.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "account-abstraction/core/Helpers.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes data);
    // entrypoint -> this contract
    IEntryPoint private immutable i_entryPoint;

    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external requireFromEntryPoint returns (uint256 validationData) {
        validationData = _validateSignature(userOp, userOpHash);
        if (validationData != SIG_VALIDATION_SUCCESS) {
            return validationData;
        }
        // Placeholder for other validation steps:
        // _validateNonce(userOp.nonce); // Important for replay protection
        _payPrefund(missingAccountFunds); // Logic to pay the EntryPoint if needed​
        // If all checks pass up to this point, including signature.
        // For this lesson, we are only focusing on signature validation for the return.
        // In a complete implementation, if nonce and prefund also passed,
        // we'd still return the validationData which might be SIG_VALIDATION_SUCCESS
        // or a packed value if using timestamps.

        return validationData; // This will be SIG_VALIDATION_SUCCESS or SIG_VALIDATION_FAILED from _validateSignature
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external requireFromEntryPointOrOwner {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view returns (uint256 validationData) {
        // Signature validation logic will be implemented here
        // A signature is valid if it's from the MinimalAccount owner
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            userOpHash
        );
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

        if (signer == address(0) || signer != owner()) {
            // Also check for invalid signature recovery
            return SIG_VALIDATION_FAILED; // Returns 1
        }

        return SIG_VALIDATION_SUCCESS; // Returns 0
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        // Logic to pay the EntryPoint if needed
        // For simplicity, this is left unimplemented in this minimal example
        if (missingAccountFunds > 0) {
            // In a real implementation, you would transfer funds to the EntryPoint here
            (bool success, ) = payable(msg.sender).call{
                value: missingAccountFunds,
                gas: type(uint256).max
            }("");
            (success); // suppress warning
        }
    }

    /*///////////////////////////////////////
                GETTERS
    //////////////////////////////////////*/
    function getEntryPoint() public view returns (address) {
        return address(i_entryPoint);
    }
}
