// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

contract MockVerifier {

    function verifyProof(
        uint[2] calldata /*_pA*/, 
        uint[2][2] calldata /*_pB*/, 
        uint[2] calldata /*_pC*/, 
        uint[3] calldata /*_pubSignals*/
    ) public pure returns (bool) {
        return true;
    }
}