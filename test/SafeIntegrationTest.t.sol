// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {SoulboundToken} from "../src/SoulboundToken.sol";
import {Safe} from "lib/safe-contracts/contracts/Safe.sol";
import {SafeProxyFactory} from "lib/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import {Enum} from "lib/safe-contracts/contracts/common/Enum.sol";

error OwnableUnauthorizedAccount(address account);

contract SafeIntegrationTest is Test {
    Safe public safe;
    SoulboundToken public sbt;
    address public owner;

    function setUp() public {
        // Create test address
        owner = makeAddr("owner");
        vm.deal(owner, 100 ether);
        
        vm.startPrank(owner);

        // Deploy Safe factory and master copy
        Safe safeMasterCopy = new Safe();
        SafeProxyFactory safeFactory = new SafeProxyFactory();

        // Setup Safe configuration
        address[] memory owners = new address[](1);
        owners[0] = owner;

        bytes memory initializer = abi.encodeWithSelector(
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

        // Deploy Safe proxy
        safe = Safe(payable(address(safeFactory.createProxyWithNonce(
            address(safeMasterCopy),
            initializer,
            uint256(blockhash(block.number - 1)) // using previous block hash as nonce
        ))));

        // Deploy Soulbound Token
        sbt = new SoulboundToken();
        
        // Transfer ownership to Safe
        sbt.transferOwnership(address(safe));

        vm.stopPrank();
    }

    function testSafeMintNFT() public {
        vm.startPrank(owner);

        // Create mint transaction data
        bytes memory mintData = abi.encodeWithSelector(
            SoulboundToken.mint.selector,
            owner,
            1  // tokenId
        );

        // Create signature for safe transaction
        bytes32 txHash = safe.getTransactionHash(
            address(sbt),              // to
            0,                         // value
            mintData,                  // data
            Enum.Operation.Call,       // operation
            0,                         // safeTxGas
            0,                         // baseGas
            0,                         // gasPrice
            address(0),                // gasToken
            payable(0),                // refundReceiver
            safe.nonce()              // nonce
        );

        // Get owner's private key from the test address label
        uint256 privateKey = uint256(keccak256(abi.encodePacked("owner")));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, txHash);
        
        // Format signature according to EIP-712
        bytes memory signature = abi.encodePacked(r, s, v, uint256(0));

        // Execute mint through Safe
        bool success = safe.execTransaction(
            address(sbt),              // to
            0,                         // value
            mintData,                  // data
            Enum.Operation.Call,       // operation
            0,                         // safeTxGas
            0,                         // baseGas
            0,                         // gasPrice
            address(0),                // gasToken
            payable(0),                // refundReceiver
            signature                  // signatures
        );

        require(success, "Safe transaction failed");

        // Verify mint was successful
        assertEq(sbt.ownerOf(1), owner);
        assertEq(sbt.balanceOf(owner), 1);

        vm.stopPrank();
    }

    function testCannotMintDirectly() public {
        vm.startPrank(owner);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                owner
            )
        );
        sbt.mint(owner, 1);

        vm.stopPrank();
    }
}