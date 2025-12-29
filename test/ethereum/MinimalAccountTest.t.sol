// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";
import {DeployMinimalAccount} from "../../script/DeployMinimal.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation} from "../../script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;

    address randomuser = makeAddr("randomuser");

    function setUp() public {
        DeployMinimalAccount deployer = new DeployMinimalAccount();
        (helperConfig, minimalAccount) = deployer.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    // USDC Approval

    // msg.sender -> MinimalAccount
    // approve some amount
    // USDC contract
    // come from the entrypoint

    function testOwnerCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            1000 ether
        );
        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, data);

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), 1000 ether);
    }

    function testNonOwnerCannotExecuteCommands() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            1000 ether
        );
        // Act
        vm.prank(address(1234));
        vm.expectRevert(
            MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector
        );
        minimalAccount.execute(dest, value, data);
    }

    function testRecoverSignedOp() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            1000 ether
        );
        bytes memory executeCallData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            data
        );
        (PackedUserOperation memory userOp, bytes32 digest) = sendPackedUserOp
            .generateSignedUserOp(
                executeCallData,
                helperConfig.getConfig(),
                address(minimalAccount)
            );
        // bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint)
        //     .getUserOpHash(userOp);
        // // Act
        // address actualSigner = ECDSA.recover(
        //     userOpHash.toEthSignedMessageHash(),
        //     userOp.signature
        // );
        address actualSigner = ECDSA.recover(digest, userOp.signature);
        // Assert
        assertEq(actualSigner, minimalAccount.owner());
    }

    function testValidationOfUserOps() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            1000 ether
        );
        bytes memory executeCallData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            data
        );
        (PackedUserOperation memory userOp, bytes32 digest) = sendPackedUserOp
            .generateSignedUserOp(
                executeCallData,
                helperConfig.getConfig(),
                address(minimalAccount)
            );

        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint)
            .getUserOpHash(userOp);

        // Act
        vm.prank(address(helperConfig.getConfig().entryPoint));
        uint256 validationData = minimalAccount.validateUserOp(
            userOp,
            userOpHash,
            1e18
        );
        assertEq(validationData, 0); // SIG_VALIDATION_SUCCESS is 0
    }

    function testEntryPointCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            1000 ether
        );
        bytes memory executeCallData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            data
        );
        (PackedUserOperation memory userOp, bytes32 digest) = sendPackedUserOp
            .generateSignedUserOp(
                executeCallData,
                helperConfig.getConfig(),
                address(minimalAccount)
            );

        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint)
            .getUserOpHash(userOp);

        vm.deal(address(minimalAccount), 1e18); // Fund the account to pay prefund
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        // Act
        vm.prank(randomuser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(
            ops,
            payable(randomuser)
        );

        //assert
        assertEq(usdc.balanceOf(address(minimalAccount)), 1000 ether);
    }
}
