// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Safe} from "lib/safe-contracts/contracts/Safe.sol";
import {SafeProxyFactory} from "lib/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import {Enum} from "lib/safe-contracts/contracts/common/Enum.sol";
import {SoulboundToken} from "../src/SoulboundToken.sol";
import "forge-std/console.sol";

contract SafeIntegrationTest is Test {
    Safe public parentSafe;
    address public owner1;
    address public owner2;
    uint256 public owner1PrivateKey;
    uint256 public owner2PrivateKey;

    function setUp() public {
        owner1PrivateKey = uint256(keccak256(abi.encodePacked("owner1")));
        owner2PrivateKey = uint256(keccak256(abi.encodePacked("owner2")));
        owner1 = vm.addr(owner1PrivateKey);
        owner2 = vm.addr(owner2PrivateKey);
        vm.deal(owner1, 100 ether);
        vm.deal(owner2, 100 ether);
        
        vm.startPrank(owner1);

        // Deploy Safe master copy
        Safe safeMasterCopy = new Safe();
        
        // Deploy factory
        SafeProxyFactory safeFactory = new SafeProxyFactory();

        // Setup owners array
        address[] memory owners = new address[](1);
        owners[0] = owner1;

        // Create initializer data
        bytes memory initializer = abi.encodeWithSelector(
            Safe.setup.selector,
            owners,                     // owners
            1,                         // threshold
            address(0),                // to
            bytes(""),                 // data
            address(0x1),             // fallbackHandler
            address(0),                // payment token
            0,                         // payment
            address(0)                 // payment receiver
        );

        // Deploy proxy pointing to the master copy
        parentSafe = Safe(payable(
            address(safeFactory.createProxyWithNonce(
                address(safeMasterCopy),
                initializer,
                uint256(keccak256(abi.encodePacked("salt")))
            ))
        ));

        // Store the reference to the deployed Safe
        assertTrue(address(parentSafe) != address(0), "Safe deployment failed");
        
        vm.stopPrank();
    }

    function testChangeOwner() public {
        // First, add owner2 before removing owner1
        bytes memory txData = abi.encodeWithSelector(
            parentSafe.addOwnerWithThreshold.selector,
            owner2,
            1
        );

        bytes32 txHash = parentSafe.getTransactionHash(
            address(parentSafe),
            0,
            txData,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            address(0),
            parentSafe.nonce()
        );

        assertTrue(parentSafe.isOwner(owner1), "owner1 should be initial owner");
        assertEq(parentSafe.getThreshold(), 1, "Initial threshold should be 1");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1PrivateKey, txHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(owner1);
        parentSafe.execTransaction(
            address(parentSafe),
            0,
            txData,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signature
        );

        // Then remove owner1
        txData = abi.encodeWithSelector(
            parentSafe.removeOwner.selector,
            owner2, // prevOwner - now owner2 is in the list
            owner1, // owner to remove
            1      // new threshold
        );

        txHash = parentSafe.getTransactionHash(
            address(parentSafe),
            0,
            txData,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            address(0),
            parentSafe.nonce()
        );

        (v, r, s) = vm.sign(owner1PrivateKey, txHash);
        signature = abi.encodePacked(r, s, v);

        parentSafe.execTransaction(
            address(parentSafe),
            0,
            txData,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signature
        );

        // Verify ownership change
        assertFalse(parentSafe.isOwner(owner1));
        assertTrue(parentSafe.isOwner(owner2));
        assertEq(parentSafe.getThreshold(), 1);
    }
}