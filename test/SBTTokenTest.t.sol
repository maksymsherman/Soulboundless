// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/SoulboundToken.sol";

error ERC721InvalidSender(address sender);
error ERC721InvalidReceiver(address receiver);
error OwnableUnauthorizedAccount(address account);

contract SoulboundTokenTest is Test {
    SoulboundToken public sbt;
    address public owner;
    address public alice;
    address public bob;

    event SoulboundTokenMinted(address indexed to, uint256 indexed tokenId);

    function setUp() public {
        sbt = new SoulboundToken();
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    function test_CorrectTokenName() public view {
        assertEq(sbt.name(), "SoulboundToken");
        assertEq(sbt.symbol(), "SBT");
    }

    function test_Mint() public {
        sbt.mint(alice, 1);
        assertEq(sbt.ownerOf(1), alice);
        assertEq(sbt.balanceOf(alice), 1);
    }

    function test_RevertWhen_NonOwnerMints() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        sbt.mint(bob, 1);
    }

    function test_MultipleMint() public {
        sbt.mint(alice, 1);
        sbt.mint(bob, 2);
        
        assertEq(sbt.ownerOf(1), alice);
        assertEq(sbt.ownerOf(2), bob);
        assertEq(sbt.balanceOf(alice), 1);
        assertEq(sbt.balanceOf(bob), 1);
    }

    function test_RevertWhen_TransferAttempted() public {
        sbt.mint(alice, 1);
        
        vm.prank(alice);
        vm.expectRevert("This token is non-transferable");
        sbt.transferFrom(alice, bob, 1);
    }

    function test_RevertWhen_ApproveAttempted() public {
        sbt.mint(alice, 1);
        
        vm.prank(alice);
        vm.expectRevert("This token is non-transferable");
        sbt.approve(bob, 1);
    }

    function test_RevertWhen_SetApprovalForAllAttempted() public {
        sbt.mint(alice, 1);
        
        vm.prank(alice);
        vm.expectRevert("This token is non-transferable");
        sbt.setApprovalForAll(bob, true);
    }

    function test_RevertWhen_DuplicateMint() public {
        sbt.mint(alice, 1);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721InvalidSender.selector,
                address(0)
            )
        );
        sbt.mint(bob, 1);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721InvalidReceiver.selector,
                address(0)
            )
        );
        sbt.mint(address(0), 1);
    }

    function test_RevertWhen_SafeTransferAttempted() public {
        sbt.mint(alice, 1);
        
        vm.prank(alice);
        vm.expectRevert("This token is non-transferable");
        sbt.safeTransferFrom(alice, bob, 1);
    }

    function test_RevertWhen_SafeTransferWithDataAttempted() public {
        sbt.mint(alice, 1);
        bytes memory data = "";
        
        vm.prank(alice);
        vm.expectRevert("This token is non-transferable");
        sbt.safeTransferFrom(alice, bob, 1, data);
    }

    function test_MintEmitsCorrectEvent() public {
        vm.expectEmit(true, true, false, true);
        emit SoulboundTokenMinted(alice, 1);
        sbt.mint(alice, 1);
    }
}