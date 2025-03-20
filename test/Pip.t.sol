// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {Pip, IERC20, PoseidonT3, IGroth16Verifier} from "../src/Pip.sol"; 
import {SoloVerifier} from "../src/SoloVerifier.sol";
import {MockVerifier} from "./MockVerifier.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// placeholder for pip test tree height 12.
contract PipTest is Test {

    address constant ALICE = address(0xA11C3); // uint256(uint160(ALICE)) = 659907
    address constant BOB = address(0xB0B); // uint256(uint160(BOB)) = 2827
    address constant CHARLIE = address(0xC); // 12
    address constant RELAYER = address(0x1337);
    address constant OWNER = address(0xDAD);

    uint256 constant INITIAL_ETH = 1000e18;
    uint256 constant INITIAL_TOKENS = 1000000e18;
    
    uint256 public constant ZERO_VALUE = 11122724670666931127833274645309940916396779779585410472511079044548860378081; // Z0
    uint256 public constant Z1 = 1891682660472723078494341181381562966782342654802963640713393672196777141865; // (Z0.Z0)
    uint256 public constant Z2 = 11753225569593816999506130861675823105515818441245022216567454953943371433075; // (Z1.Z1)
    uint256 public constant Z3 = 21220542571259101805024786323770586210738494005346819350584272402182380114809; // (Z2.Z2)
    uint256 public constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 public constant COMMITMENT_CONSTANT = 69420; // Commitment = PoseidonT3(nullifier,69420)
    uint256 public constant HEIGHT = 12;
    uint256 public constant OWNER_FEE = 20; // 0.2%
    uint256 public constant RELAYER_FEE = 5; // 0.05%
    uint256 public constant GAS = 1e14;

    enum ProofType {
        Gas,
        Withdraw
    }

    Pip public pip;
    IGroth16Verifier public verifier;
    IGroth16Verifier public mockVerifier;
    ERC20Mock public token;


    function setUp() public {
        verifier = IGroth16Verifier(address(new SoloVerifier()));
        mockVerifier = IGroth16Verifier(address(new MockVerifier()));
        token = new ERC20Mock();
        vm.deal(ALICE, INITIAL_ETH);
        vm.deal(BOB, INITIAL_ETH);
        vm.deal(RELAYER, INITIAL_ETH);
        vm.deal(OWNER, INITIAL_ETH);
        token.mint(ALICE, INITIAL_TOKENS);
        token.mint(BOB, INITIAL_TOKENS);
    }


    //=================================================
    //=============== HELPER FUNCTIONS ================
    //=================================================
    function deployPool(bool isMock, uint256 _denomination, bool isETH) public {
        vm.startPrank(OWNER);
        pip = new Pip(isMock ? mockVerifier : verifier, _denomination, isETH ? IERC20(address(0)) : token);
        vm.stopPrank();
    }

    function createNullifier(bytes32 _seed) public pure returns (uint256) {
        uint256 nullifier = uint256(keccak256(abi.encodePacked(_seed))) % FIELD_SIZE;
        return nullifier;
    }

    function createCommitment(uint256 _nullifier) public pure returns (bytes32) {
        bytes32 commitment = bytes32(PoseidonT3.hash([_nullifier, uint256(COMMITMENT_CONSTANT)]));
        return commitment;
    }

    function createNullifierHash(uint256 _nullifier, uint256 _leafIndex) public pure returns (bytes32) {
        bytes32 nullifierHash = bytes32(PoseidonT3.hash([_nullifier, _leafIndex]));
        return nullifierHash;
    }

    //=================================================
    //================== BEGIN TESTS ==================
    //================================================= 
    function testDeployment() public {}


}