// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PlonkVerifierPPOT} from "../src/PlonkVerifierPPOT.sol";

// LOCAL: forge script script/DeployVerifier.s.sol --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast
// SEPOLIA: forge script script/DeployVerifier.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

// Only needs to be deployed once for all pip pools.
contract DeployVerifier is Script {

    function run() public {
        vm.startBroadcast();
        PlonkVerifierPPOT verifier = new PlonkVerifierPPOT();
        console.log("Deployed PlonkVerifierPPOT.sol at addres: ", address(verifier));
        vm.stopBroadcast();
    }
}