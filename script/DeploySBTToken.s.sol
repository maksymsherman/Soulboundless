// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {SoulboundToken} from "../src/SoulboundToken.sol";
import {Safe} from "@safe-global/safe-contracts/contracts/Safe.sol";
import {SafeProxyFactory} from "@safe-global/safe-contracts/contracts/proxies/SafeProxyFactory.sol";

contract DeployToken is Script {
    function run() external {
        address owner = msg.sender;
        
        vm.startBroadcast();

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
        Safe safe = Safe(payable(address(safeFactory.createProxy(
            address(safeMasterCopy),
            initializer
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