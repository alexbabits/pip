// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Pip, IERC20, IGroth16Verifier} from "../src/Pip.sol";

// forge script script/DeployPip.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
contract DeployPip is Script {

    function run() public {
        vm.startBroadcast();

        // Input actual values when deploying
        IGroth16Verifier verifier = IGroth16Verifier(address(0x69));
        IERC20 token = IERC20(address(69)); 
        uint256 denomination = 69;

        Pip pip = new Pip(verifier, denomination, token);
        console.log("Deployed Pip.sol at address: ", address(pip));
        
        vm.stopBroadcast();
    }
}