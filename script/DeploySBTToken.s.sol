// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {SoulboundToken} from "../src/SoulboundToken.sol";

contract DeployOurToken is Script {
    function run() external {
        vm.startBroadcast();

        SoulboundToken token = new SoulboundToken();
        
        vm.stopBroadcast();

        console.log("SoulboundToken deployed to:", address(token));
    }
}