// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {SoulboundToken} from "../src/SoulboundToken.sol";
import {Safe} from "lib/safe-contracts/contracts/Safe.sol";
import {SafeProxyFactory} from "lib/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import {Enum} from "lib/safe-contracts/contracts/common/Enum.sol";

contract DeployToken is Script {
    function run() external {
        uint256 owner1PrivateKey = uint256(keccak256(abi.encodePacked("owner1")));
        address owner = vm.addr(owner1PrivateKey);
        
        vm.startBroadcast();

        // Deploy Safe master copy
        Safe safeMasterCopy = new Safe();
        
        // Deploy factory
        SafeProxyFactory safeFactory = new SafeProxyFactory();

        // Setup owners array
        address[] memory owners = new address[](1);
        owners[0] = owner;

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

        // Deploy Safe proxy with nonce
        Safe safe = Safe(payable(address(safeFactory.createProxyWithNonce(
            address(safeMasterCopy),
            initializer,
            uint256(keccak256(abi.encodePacked("salt"))) // match test nonce
        ))));

        // Deploy Soulbound Token
        SoulboundToken token = new SoulboundToken();
        
        // Transfer ownership to Safe
        token.transferOwnership(address(safe));
        
        vm.stopBroadcast();

        console.log("Safe deployed to:", address(safe));
        console.log("SoulboundToken deployed to:", address(token));
    }
}