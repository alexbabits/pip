// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity 0.8.28;

// Note: This verifier was created from the `height4` withdraw.circom circuit (TREE HEIGHT 4)
// Note: The groth16 trusted setup was just done SOLO and therefore insecure/requires trust, but sufficient for testing verification process.
contract SoloVerifier4 {
    // Scalar field size
    uint256 constant r    = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q   = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax  = 17528357333642583053353304747713752058838651702776594288091441609097871412019;
    uint256 constant alphay  = 11994674298726549914451340320447553943275264964517484774324800651453230302181;
    uint256 constant betax1  = 9280456155923773902376944612032773245639391898793881232325769462961453455974;
    uint256 constant betax2  = 9089351638046649616892024931137973453205790732896267111201011390013964875505;
    uint256 constant betay1  = 3247365439804111895154725521352386438360404414791100201685957330525127728960;
    uint256 constant betay2  = 9393521850206004988535182715323621844152635213158867146574129260958212731436;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 3696411453609010040440080657549922836455644452800454101646367357796895961333;
    uint256 constant deltax2 = 14227857051702129233836372117077405765368892786851428303997516589519911872576;
    uint256 constant deltay1 = 17295643597307493548542881969962434115002856302704156977013763026978858670056;
    uint256 constant deltay2 = 12917928608723514958481432531776364341664913439206196412703698991910482271168;

    
    uint256 constant IC0x = 6641877524587138670492339338250519443790476748789900217433238394795812868208;
    uint256 constant IC0y = 16978930422384311045742608878787848521995659280764030255032623288106978260168;
    
    uint256 constant IC1x = 12672494650053120042878610967472556128683185613396311165706459512738610786021;
    uint256 constant IC1y = 14435571299883183075677015060575982251771927410834961846945189927688243918038;
    
    uint256 constant IC2x = 8824989963982574367826577249185411105370958714421527215989124471972042579125;
    uint256 constant IC2y = 9914406542115847958115318303084482188140258559513827420514043241103071620089;
    
    uint256 constant IC3x = 12736538425164983204113475184920717564580071065733131904930328008868693527642;
    uint256 constant IC3y = 9144978106362581377091195997698465305676790927989542008296660589079376568634;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;
    
    // e(A,B)=e(α,β)+e(vkx,γ)+e(C,δ)
    // A,B,C = Proof elements
    // α,β,γ,δ = Verifying key elements
    // vkx = Linear combination of public inputs and verification key
    // 1. Checks field validity → Ensures public inputs belong to the right field.
    // 2. Computes the linear combination of public signals → Uses g1_mulAccC to accumulate values.
    // 3. Performs the pairing check → Calls checkPairing to verify:
    // 4. e(-A,B)=e(α,β)+e(vkx,γ)+e(C,δ) = 0
    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[3] calldata _pubSignals) public view returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, r)) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }
            
            // G1 function to multiply a G1 value(x,y) to value in an address
            function g1_mulAccC(pR, x, y, s) {
                let success
                let mIn := mload(0x40)
                mstore(mIn, x)
                mstore(add(mIn, 32), y)
                mstore(add(mIn, 64), s)

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
                let _pPairing := add(pMem, pPairing)
                let _pVk := add(pMem, pVk)

                mstore(_pVk, IC0x)
                mstore(add(_pVk, 32), IC0y)

                // Compute the linear combination vk_x
                
                g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))
                
                g1_mulAccC(_pVk, IC2x, IC2y, calldataload(add(pubSignals, 32)))
                
                g1_mulAccC(_pVk, IC3x, IC3y, calldataload(add(pubSignals, 64)))
                

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(add(_pPairing, 32), mod(sub(q, calldataload(add(pA, 32))), q))

                // B
                mstore(add(_pPairing, 64), calldataload(pB))
                mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
                mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
                mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

                // alpha1
                mstore(add(_pPairing, 192), alphax)
                mstore(add(_pPairing, 224), alphay)

                // beta2
                mstore(add(_pPairing, 256), betax1)
                mstore(add(_pPairing, 288), betax2)
                mstore(add(_pPairing, 320), betay1)
                mstore(add(_pPairing, 352), betay2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))


                // gamma2
                mstore(add(_pPairing, 448), gammax1)
                mstore(add(_pPairing, 480), gammax2)
                mstore(add(_pPairing, 512), gammay1)
                mstore(add(_pPairing, 544), gammay2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), deltax1)
                mstore(add(_pPairing, 672), deltax2)
                mstore(add(_pPairing, 704), deltay1)
                mstore(add(_pPairing, 736), deltay2)


                let success := staticcall(sub(gas(), 2000), 8, _pPairing, 768, _pPairing, 0x20)

                isOk := and(success, mload(_pPairing))
            }

            let pMem := mload(0x40)
            mstore(0x40, add(pMem, pLastMem))

            // Validate that all evaluations ∈ F
            
            checkField(calldataload(add(_pubSignals, 0)))
            
            checkField(calldataload(add(_pubSignals, 32)))
            
            checkField(calldataload(add(_pubSignals, 64)))
            
            checkField(calldataload(add(_pubSignals, 96)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
