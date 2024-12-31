// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {SafeTestTools} from "safe-tools/SafeTestTools.sol";
import {SafeTestLib} from "safe-tools/SafeTestLib.sol";
import {SafeInstance} from "safe-tools/SafeTestTypes.sol";

contract SafeIntegrationTest is Test, SafeTestTools {
    using SafeTestLib for SafeInstance;

    SafeInstance public parentSafeInstance;
    SafeInstance public childSafeInstance;
    address public owner;
    uint256 public ownerPrivateKey;

    function setUp() public {
        // Create owner private key and address
        ownerPrivateKey = uint256(keccak256(abi.encodePacked("owner")));
        owner = vm.addr(ownerPrivateKey);
        vm.deal(owner, 100 ether);
        
        // Setup parent safe with single owner
        uint256[] memory ownerPKs = new uint256[](1);
        ownerPKs[0] = ownerPrivateKey;
        parentSafeInstance = _setupSafe(
            ownerPKs,     // owner private keys
            1,           // threshold
            100 ether    // initial balance
        );

        // Setup child safe with parent safe as owner
        address[] memory childOwners = new address[](1);
        childOwners[0] = address(parentSafeInstance.safe);
        
        // Create child safe instance
        uint256[] memory childOwnerPKs = new uint256[](1);
        childOwnerPKs[0] = ownerPrivateKey; // We'll use same key for signing parent transactions
        childSafeInstance = _setupSafe(
            childOwnerPKs,
            1,
            50 ether
        );

        // Transfer ownership to parent safe
        vm.startPrank(owner);
        childSafeInstance.safe.setup(
            childOwners,               // owners
            1,                         // threshold
            address(0),                // to
            bytes(""),                 // data
            address(0),                // fallback handler
            address(0),                // payment token
            0,                         // payment
            payable(address(0))        // payment receiver
        );
        vm.stopPrank();
    }

    function testSafeSetup() public {
        // Verify parent safe owner was set correctly
        assertTrue(parentSafeInstance.safe.isOwner(owner));
        assertEq(parentSafeInstance.safe.getThreshold(), 1);

        // Verify child safe owner is the parent safe
        assertTrue(childSafeInstance.safe.isOwner(address(parentSafeInstance.safe)));
        assertEq(childSafeInstance.safe.getThreshold(), 1);
    }

    function testParentControlsChild() public {
        address recipient = address(0xBEEF);
        uint256 amount = 1 ether;
        
        // Parent safe initiates transfer from child safe
        bytes memory transferCalldata = abi.encodeWithSignature(
            "execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)",
            recipient,
            amount,
            "",
            0, // Call
            0, // safeTxGas
            0, // baseGas  
            0, // gasPrice
            address(0), // gasToken
            payable(address(0)), // refundReceiver
            "" // signatures - will be added by execTransaction
        );

        // Execute transfer through parent safe
        parentSafeInstance.execTransaction(
            address(childSafeInstance.safe),
            0,
            transferCalldata
        );

        // Verify transfer was successful
        assertEq(recipient.balance, amount);
    }
}