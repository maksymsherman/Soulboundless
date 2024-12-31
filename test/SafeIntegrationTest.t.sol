// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Safe} from "lib/safe-contracts/contracts/Safe.sol";
import {SafeProxyFactory} from "lib/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import {SafeTestTools, SafeInstance} from "safe-tools/SafeTestTools.sol";
import {Enum} from "lib/safe-contracts/contracts/common/Enum.sol";

contract SafeIntegrationTest is Test {
    Safe public parentSafe;
    Safe public childSafe;
    address public owner;
    uint256 public ownerPrivateKey;

    function setUp() public {
        // Create test address with private key
        ownerPrivateKey = uint256(keccak256(abi.encodePacked("owner")));
        owner = vm.addr(ownerPrivateKey);
        vm.deal(owner, 100 ether);
        
        vm.startPrank(owner);

        // Deploy Safe factory and master copy
        Safe safeMasterCopy = new Safe();
        SafeProxyFactory safeFactory = new SafeProxyFactory();

        // Setup Parent Safe configuration
        address[] memory owners = new address[](1);
        owners[0] = owner;

        bytes memory parentInitializer = abi.encodeWithSelector(
            Safe.setup.selector,
            owners,                     // owners
            1,                         // threshold
            address(0),                // to
            bytes(""),                 // data
            address(0),                // fallback handler
            address(0),                // payment token
            0,                         // payment
            address(0)                 // payment receiver
        );

        // Deploy Parent Safe proxy
        parentSafe = Safe(payable(address(safeFactory.createProxyWithNonce(
            address(safeMasterCopy),
            parentInitializer,
            uint256(keccak256(abi.encodePacked("parent"))) // nonce
        ))));

        // Setup Child Safe with Parent Safe as owner
        address[] memory childOwners = new address[](1);
        childOwners[0] = address(parentSafe);

        bytes memory childInitializer = abi.encodeWithSelector(
            Safe.setup.selector,
            childOwners,               // owners
            1,                         // threshold
            address(0),                // to
            bytes(""),                 // data
            address(0),                // fallback handler
            address(0),                // payment token
            0,                         // payment
            address(0)                 // payment receiver
        );

        // Deploy Child Safe proxy
        childSafe = Safe(payable(address(safeFactory.createProxyWithNonce(
            address(safeMasterCopy),
            childInitializer,
            uint256(keccak256(abi.encodePacked("child"))) // nonce
        ))));

        vm.stopPrank();
    }

    function testSafeSetup() public {
        // Verify parent safe owner was set correctly
        assertTrue(parentSafe.isOwner(owner));
        assertEq(parentSafe.getThreshold(), 1);

        // Verify child safe owner is the parent safe
        assertTrue(childSafe.isOwner(address(parentSafe)));
        assertEq(childSafe.getThreshold(), 1);
    }

    function testTransferOwnership() public {
        // First attach to the existing parent safe
        SafeTestTools safeTools = new SafeTestTools();
        SafeInstance memory parentSafeInstance = safeTools._attachToSafe(address(parentSafe));
        
        // Create new owner address
        address newOwner = makeAddr("newOwner");
        
        // 1. First add the new owner
        bytes memory addOwnerData = abi.encodeWithSelector(
            Safe.addOwnerWithThreshold.selector,
            newOwner,
            1  // keep same threshold
        );
        
        // Execute transaction to add new owner
        safeTools.execTransaction(
            parentSafeInstance,
            address(parentSafe),
            0,
            addOwnerData,
            Enum.Operation.Call
        );
        
        // 2. Then remove the old owner
        bytes memory removeOwnerData = abi.encodeWithSelector(
            Safe.removeOwner.selector,
            address(0), // prevOwner - will be automatically handled since we have one owner
            owner,      // owner to remove
            1          // new threshold
        );
        
        // Execute transaction to remove old owner
        safeTools.execTransaction(
            parentSafeInstance,
            address(parentSafe),
            0,
            removeOwnerData,
            Enum.Operation.Call
        );
        
        // Verify ownership transfer
        assertTrue(parentSafe.isOwner(newOwner));
        assertFalse(parentSafe.isOwner(owner));
        assertEq(parentSafe.getThreshold(), 1);
    }
}