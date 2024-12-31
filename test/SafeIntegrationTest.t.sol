// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/SoulboundToken.sol";
import "@safe-global/safe-contracts/contracts/Safe.sol";
import "@safe-global/safe-contracts/contracts/proxies/SafeProxyFactory.sol";

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
        safe = Safe(payable(address(safeFactory.createProxy(
            address(safeMasterCopy),
            initializer
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

        // Execute mint through Safe
        safe.execTransaction(
            address(sbt),              // to
            0,                         // value
            mintData,                  // data
            Enum.Operation.Call,       // operation
            0,                         // safeTxGas
            0,                         // baseGas
            0,                         // gasPrice
            address(0),                // gasToken
            payable(0),                // refundReceiver
            abi.encodePacked(          // signatures
                uint256(0),
                uint256(0),
                uint8(0)
            )
        );

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