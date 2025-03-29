// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

contract MockVerifier {

    function verifyProof(
        uint[24] calldata, /* proof*/
        uint[5] calldata /*_pubSignals*/
    ) public pure returns (bool) {
        return true;
    }
}