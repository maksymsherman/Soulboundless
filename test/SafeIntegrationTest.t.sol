// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "./SafeTestTools.sol";
import "safe-contracts/Safe.sol";
import "safe-contracts/proxies/SafeProxyFactory.sol";
import "safe-contracts/common/Enum.sol";

contract SafeIntegrationTest is Test, SafeTestTools {
    using SafeTestLib for SafeInstance;
    
    SafeInstance public parentSafe;
    SafeInstance public childSafe;
    uint256 public ownerPrivateKey;

    function setUp() public {
        // Create owner key
        ownerPrivateKey = uint256(keccak256(abi.encodePacked("owner")));
        vm.label(vm.addr(ownerPrivateKey), "Owner");

        // Setup parent safe with single owner
        uint256[] memory parentPKs = new uint256[](1);
        parentPKs[0] = ownerPrivateKey;
        
        parentSafe = _setupSafe(
            parentPKs,    // owner private keys
            1,           // threshold
            100 ether    // initial balance
        );

        // Setup child safe with parent safe as owner
        address[] memory childOwners = new address[](1);
        childOwners[0] = address(parentSafe.safe);

        // Create child safe with same signing key
        uint256[] memory childPKs = new uint256[](1);
        childPKs[0] = ownerPrivateKey;

        childSafe = _setupSafe(
            childPKs,
            1,
            50 ether
        );

        // Transfer ownership to parent safe
        vm.startPrank(vm.addr(ownerPrivateKey));
        childSafe.safe.setup(
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
        assertTrue(parentSafe.safe.isOwner(vm.addr(ownerPrivateKey)));
        assertEq(parentSafe.safe.getThreshold(), 1);

        // Verify child safe owner is the parent safe
        assertTrue(childSafe.safe.isOwner(address(parentSafe.safe)));
        assertEq(childSafe.safe.getThreshold(), 1);
    }

    function testParentControlsChild() public {
        address recipient = address(0xBEEF);
        uint256 amount = 1 ether;

        // Parent safe initiates transfer from child safe
        bytes memory transferCalldata = abi.encodeWithSelector(
            Safe.execTransaction.selector,
            recipient,
            amount,
            "",             // data
            Enum.Operation.Call,
            0,              // safeTxGas
            0,              // baseGas
            0,              // gasPrice
            address(0),     // gasToken
            payable(address(0)), // refundReceiver
            ""             // signatures - will be added by execTransaction
        );

        // Execute transfer through parent safe using SafeTestLib helper
        parentSafe.execTransaction(
            address(childSafe.safe),
            0,
            transferCalldata
        );

        // Verify transfer was successful
        assertEq(recipient.balance, amount);
    }

    function testModuleManagement() public {
        address mockModule = address(0xDEAD);
        
        // Enable module through parent safe
        bytes memory enableModuleData = abi.encodeWithSelector(
            ModuleManager.enableModule.selector,
            mockModule
        );

        parentSafe.execTransaction(
            address(childSafe.safe),
            0,
            enableModuleData
        );

        // Verify module was enabled
        assertTrue(childSafe.safe.isModuleEnabled(mockModule));

        // Disable module
        bytes memory disableModuleData = abi.encodeWithSelector(
            ModuleManager.disableModule.selector,
            address(SENTINEL_MODULES),  // prev module
            mockModule
        );

        parentSafe.execTransaction(
            address(childSafe.safe),
            0,
            disableModuleData
        );

        // Verify module was disabled
        assertFalse(childSafe.safe.isModuleEnabled(mockModule));
    }
}