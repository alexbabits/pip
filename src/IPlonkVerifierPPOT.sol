// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;  

interface IPlonkVerifierPPOT {
    function verifyProof(
        uint[24] calldata _proof, 
        uint[5] calldata _pubSignals
    ) external view returns (bool);
}