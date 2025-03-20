// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Pip4, IERC20, PoseidonT3, IGroth16Verifier} from "./Pip4.sol"; 
import {SoloVerifier4} from "./SoloVerifier4.sol";
import {MockVerifier} from "../MockVerifier.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Legacy tests using merkle tree of height 4 for exhaustive multi-tree testing. (Tree resets & non-zero tree indices)
contract Pip4Test is Test {

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
    uint256 public constant HEIGHT = 4;
    uint256 public constant OWNER_FEE = 20; // 0.2%
    uint256 public constant RELAYER_FEE = 5; // 0.05%
    uint256 public constant GAS = 1e14;

    enum ProofType {
        Gas,
        Withdraw
    }

    Pip4 public pip;
    IGroth16Verifier public verifier;
    IGroth16Verifier public mockVerifier;
    ERC20Mock public token;


    function setUp() public {
        verifier = IGroth16Verifier(address(new SoloVerifier4()));
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
        pip = new Pip4(isMock ? mockVerifier : verifier, _denomination, isETH ? IERC20(address(0)) : token);
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
    function testDeployment() public {
        uint256 _denomination = 1e18;
        deployPool(false, _denomination, true);

        assertEq(pip.denomination(), _denomination, "should match");
        assertEq(address(pip.token()), address(0), "should be 0x0 for ETH");

        bytes32 Z0solidity = keccak256(abi.encodePacked("Pulse In Private"));
        bytes32 Z1solidity = pip.poseidonHash(Z0solidity, Z0solidity);
        bytes32 Z2solidity = pip.poseidonHash(Z1solidity, Z1solidity);
        bytes32 Z3solidity = pip.poseidonHash(Z2solidity, Z2solidity);

        bytes32[4] memory solidityPoseidon = [Z0solidity, Z1solidity, Z2solidity, Z3solidity];
        // generated from `../tree/build-tree.js`
        bytes32[4] memory jsPoseidon = [
            bytes32(0x18973d339bc06ed46f1d7aa1d8265b6688eaf583b4731e7c551c05c789dcfbe1),
            bytes32(0x042ea78997ff74a8d42c56cfdd623c85f4f1ce5df14610f4466be22faf5d6669),
            bytes32(0x19fc1705bb463e42aa596ab5f64c49bbf316112e97220b359a2901f12b4d4473),
            bytes32(0x2eea66c6432bae9767fd0791dbdc627320f6e971a4cc3861cb4f0d3e92aed379)
        ];        

        for (uint256 i = 0; i < HEIGHT; i++) {
            assertEq(solidityPoseidon[i], jsPoseidon[i], string(abi.encodePacked("incorrect at index ", vm.toString(i))));
        }

        for (uint256 i = 0; i < HEIGHT; i++) {
            assertEq(pip.zeros(i), jsPoseidon[i], string(abi.encodePacked("incorrect at index ", vm.toString(i))));
        }
    }


    function testDepositETH() public {
        uint256 _denomination = 1e18;
        deployPool(false, _denomination, true);

        //                 /\
        //                /  \
        //               /    \
        //              /  #0  \
        //             /________\        /\  
        //                 ||           /__\     
        // O__/\_/\____O___||__/\__O__O__||____O___/\___

        vm.startPrank(ALICE);

        // Cannot deposit amount other than (_denomination + GAS)
        uint256 nullifier = createNullifier(bytes32(uint256(69420)));
        bytes32 c0 = createCommitment(nullifier);
        vm.expectRevert(abi.encodeWithSelector(Pip4.IncorrectPayment.selector));
        pip.deposit{value: _denomination + GAS - 1}(c0);
        vm.expectRevert(abi.encodeWithSelector(Pip4.IncorrectPayment.selector));
        pip.deposit{value: _denomination + GAS + 1}(c0);
        vm.expectRevert(abi.encodeWithSelector(Pip4.IncorrectPayment.selector));
        pip.deposit{value: GAS}(c0);
        vm.expectRevert(abi.encodeWithSelector(Pip4.IncorrectPayment.selector));
        pip.deposit{value: 0}(c0);

        // FIRST DEPOSIT
        // (topic1, topic2, topic3, data)
        // leaf, leafindex, treeindex, root
        vm.expectEmit(true, true, true, true); 
        emit Pip4.Deposit(c0, 0, 0, 0x1fbc1a3e387b8f5005c80ac46239dd4309fee036b476ceb05d53743a1e549225); 
        pip.deposit{value: _denomination + GAS}(c0);

        assertEq(address(pip).balance, _denomination + GAS, "should get deposit and gas");
        assertEq(ALICE.balance, INITIAL_ETH - _denomination - GAS, "should have paid denomination and gas");
        assertEq(pip.commitments(c0), true, "Deposit commitment should now exist in mapping");
        assertEq(pip.leafIndex(), 1, "should have incremented");

        // Cannot deposit again with same commitment
        vm.expectRevert(abi.encodeWithSelector(Pip4.CommitmentAlreadyInTree.selector));
        pip.deposit{value: _denomination}(c0);
        

        // SECOND DEPOSIT
        uint256 nullifier1 = createNullifier(bytes32(uint256(1337)));
        bytes32 c1 = createCommitment(nullifier1);
        vm.expectEmit(true, true, true, true);
        emit Pip4.Deposit(c1, 1, 0, 0x2525a57bd217c7c91cc404dfd7a682c56f8a155084604057c338777598369170);
        pip.deposit{value: _denomination + GAS}(c1);

        assertEq(address(pip).balance, 2 * (_denomination + GAS), "should get deposits and gas");
        assertEq(ALICE.balance, INITIAL_ETH - 2 * (_denomination + GAS), "should have paid denominations and gas");
        assertEq(pip.commitments(c1), true, "Deposit commitment should exist in mapping");
        assertEq(pip.leafIndex(), 2, "should have incremented");

        // 14 DEPOSITS LATER (fill up tree, 16 total deposits now).
        for (uint256 i = 0; i < 14; i++) {
            pip.deposit{value: _denomination + GAS}(createCommitment(createNullifier(bytes32(uint256(i)))));
        }


        assertEq(address(pip).balance, 16 * (_denomination + GAS), "should get deposits and gas");
        assertEq(ALICE.balance, INITIAL_ETH - 16 * (_denomination + GAS), "should have paid denominations and gas");
        assertEq(pip.leafIndex(), 16, "should have incremented");

        vm.stopPrank();
      
        //                 /\
        //                /  \
        //               /    \
        //              /  #1  \
        //             /________\        /\  
        //                 ||           /__\     
        // O__/\_/\____O___||__/\__O__O__||____O___/\___

        vm.startPrank(BOB); // Change user to BOB

        // 17th deposit should SUCCEED and creates NEW merkle tree. (c16 = 17th deposit, 0th indexing).
        bytes32 c16 = createCommitment(createNullifier(bytes32(uint256(696969))));
        pip.deposit{value: _denomination + GAS}(c16);
        assertEq(address(pip).balance, 17 * (_denomination + GAS), "should get deposits and gas");
        assertEq(BOB.balance, INITIAL_ETH - _denomination - GAS, "should have paid denomination and gas");

        assertEq(pip.treeIndex(), 1, "should have incremented");
        // (resets to 0 but during the 17th deposit it increments it from 0 to 1
        // so we see the leaf index AFTER the first deposit of the new tree
        assertEq(pip.leafIndex(), 1, "should RESET back to 1");
        // C16 is first deposit in new tree, which is the first sibling node after the deposit.
        assertEq(pip.siblingNodes(0), c16, "should be C0");

        uint256 c0z0 = PoseidonT3.hash([uint256(c16), uint256(pip.zeros(0))]);
        assertEq(uint256(pip.siblingNodes(1)), c0z0, "Should be reset to C0.Z0");

        uint256 c0z0z1 = PoseidonT3.hash([c0z0, uint256(pip.zeros(1))]);
        assertEq(uint256(pip.siblingNodes(2)), c0z0z1, "Should be reset to C0.Z0|Z1");

        uint256 c0z0z1z2 = PoseidonT3.hash([c0z0z1, uint256(pip.zeros(2))]);
        assertEq(uint256(pip.siblingNodes(3)), c0z0z1z2, "Should be reset to C0.Z0|Z1|Z2");

        vm.stopPrank();
    }


    function testDepositERC20() public {
        uint256 _denomination = 100e18;
        deployPool(false, _denomination, false);
        
        uint256 nullifier = createNullifier(bytes32(uint256(1234)));
        bytes32 commitment = createCommitment(nullifier);

        vm.startPrank(ALICE);
        token.approve(address(pip), INITIAL_TOKENS);

        // Cannot deposit with incorrrect value attached
        vm.expectRevert(abi.encodeWithSelector(Pip4.IncorrectPayment.selector));
        pip.deposit{value: GAS + 1}(commitment);
        vm.expectRevert(abi.encodeWithSelector(Pip4.IncorrectPayment.selector));
        pip.deposit{value: GAS - 1}(commitment);
        vm.expectRevert(abi.encodeWithSelector(Pip4.IncorrectPayment.selector));
        pip.deposit{value: 0}(commitment);
        vm.expectRevert(abi.encodeWithSelector(Pip4.IncorrectPayment.selector));
        pip.deposit{value: _denomination}(commitment);
        vm.expectRevert(abi.encodeWithSelector(Pip4.IncorrectPayment.selector));
        pip.deposit{value: _denomination + GAS}(commitment);

        // Deposit only successful with GAS value attached
        pip.deposit{value: GAS}(commitment);

        // 15 DEPOSITS LATER (fill up tree, 16 total deposits now).
        for (uint256 i = 0; i < 15; i++) {
            pip.deposit{value: GAS}(createCommitment(createNullifier(bytes32(uint256(i)))));
        }

        assertEq(address(pip).balance, 16 * GAS, "should got gas");
        assertEq(address(ALICE).balance, INITIAL_ETH - 16 * GAS, "should paid gas");
        assertEq(token.balanceOf(address(pip)), 16*_denomination, "should got tokens");
        assertEq(token.balanceOf(address(ALICE)), INITIAL_TOKENS - (_denomination*16), "should paid tokens");
        vm.stopPrank();

        vm.startPrank(BOB);
        token.approve(address(pip), INITIAL_TOKENS);

        // Bob deposits 17th and creates new tree
        bytes32 c16 = createCommitment(createNullifier(bytes32(uint256(696969))));
        pip.deposit{value: GAS}(c16);
        vm.stopPrank();

        assertEq(address(pip).balance, 17*GAS, "should got gas");
        assertEq(address(BOB).balance, INITIAL_ETH - GAS, "should paid gas");
        assertEq(token.balanceOf(address(pip)), 17*_denomination, "should got tokens");
        assertEq(token.balanceOf(address(BOB)), INITIAL_TOKENS - _denomination, "should paid tokens");

        assertEq(pip.treeIndex(), 1, "should have incremented");
        assertEq(pip.leafIndex(), 1, "should RESET back to 1");
        assertEq(pip.siblingNodes(0), c16, "should be C0");

        uint256 c0z0 = PoseidonT3.hash([uint256(c16), uint256(pip.zeros(0))]);
        assertEq(uint256(pip.siblingNodes(1)), c0z0, "Should be reset to C0.Z0");

        uint256 c0z0z1 = PoseidonT3.hash([c0z0, uint256(pip.zeros(1))]);
        assertEq(uint256(pip.siblingNodes(2)), c0z0z1, "Should be reset to C0.Z0|Z1");

        uint256 c0z0z1z2 = PoseidonT3.hash([c0z0z1, uint256(pip.zeros(2))]);
        assertEq(uint256(pip.siblingNodes(3)), c0z0z1z2, "Should be reset to C0.Z0|Z1|Z2");
    }


    function testWithdrawETH() public {

        uint256 _denomination = 1e18;
        uint256 totalFee = (_denomination * (OWNER_FEE + RELAYER_FEE)) / 10000;
        uint256 ownerFee = (_denomination * OWNER_FEE) / 10000;
        uint256 relayerFee = (_denomination * RELAYER_FEE) / 10000;
        uint256 withdrawalAmount = _denomination - totalFee;
        deployPool(false, _denomination, true);

        uint256 nullifier0 = createNullifier(bytes32(uint256(0)));
        //bytes32 nullifierHash0 = createNullifierHash(nullifier0, pip.leafIndex()); // leafIndex = 0
        bytes32 c0 = createCommitment(nullifier0);

        // DEPOSIT
        vm.startPrank(ALICE);
        pip.deposit{value: _denomination + GAS}(c0);
        assertEq(address(pip).balance, _denomination + GAS, "pip got deposit");
        vm.stopPrank();

        // Data generated from `snarkjs generatecall`. circom2 docs: https://docs.circom.io/getting-started/
        // Create an `input.json` that satisfies the circuit. Create witness. Generate proof.

        // {recipient, root, nullifier, nullifierHash, pathElements, pathIndices}
        // root: Can be found by building the latest tree in build-tree.js, or looking at Deposit event.
        // nullifier & nullifierHash: console.log
        // pathElements: Found in build-tree.js (first deposit is just Z0, Z1, Z2, Z3)
        // pathIndices: The binary representation of the leafIndex.
        Pip4.ECPoints memory p;
        p.pA[0] = 0x27cf867ddb905666db1d1426ff2e375a7148e28d2c815d18c47749d1b08269eb;
        p.pA[1] = 0x1b66a6014d0abb0728262ab45d108c935cf5780d81916a90c74830b104b96c57;

        p.pB[0][0] = 0x2543004587c2d861261ffca9c667fed40fbf2ec4b87c53e1a67bf7e7c8387687;
        p.pB[0][1] = 0x2ebe2df0d725eb23e94a39900c683dd6baa1443d159a18cedb6f596ca128d69b;
        p.pB[1][0] = 0x0c37fd5c28dcd649acd6537b305b323447b2380d97972c923419e449479a52bb;
        p.pB[1][1] = 0x08fa91ea5924c9f7d8b54cb4c3c1a191ba50adc9dd94fbfd3a59d696b97bb27c;

        p.pC[0] = 0x2307be26a7efa628c744d04e026ad2e7bf68616a236f72839525b18e5019715e;
        p.pC[1] = 0x2761667d101b962096c13f6837d2e8b073a03850328b3a17a779d6eb0cd771a6;
        
        Pip4.PubSignals memory s;
        s.recipient = payable(BOB);
        s.root = 0x2130ad5394b9ce6a2fa31b9127b857eef88b9ef6c0480004006a4c6f44cb2726;
        s.nullifierHash = 0x02a48016be947d22695d63fbcb2f16964e4900062b6cc74351553b820a5bd1d0;

        // Proof is invalid if any bit of above data is incorrect

        // Pretend that BOB (recipient) is a fresh address that needs gas.
        // Relayer calls `sendGas()` on Bob's behalf.

        vm.startPrank(RELAYER);
        pip.sendGas(p,s);

        // Cannot claim gas twice with the same proof.
        vm.expectRevert(abi.encodeWithSelector(Pip4.NullifierHashAlreadyUsed.selector));
        pip.sendGas(p, s); 

        vm.stopPrank();

        assertEq(address(BOB).balance, INITIAL_ETH + (GAS * 7500 / 10000), "bob got gas");
        assertEq(address(RELAYER).balance, INITIAL_ETH + relayerFee + (GAS * 2500 / 10000), "relayer got fees");
        assertEq(address(pip).balance, _denomination - relayerFee, "pip has denomination minus relayer fee");

        // Withdraw
        vm.startPrank(BOB);
        vm.expectEmit(true, true, true, true); // (to, nullifierHash, tree index, root)
        emit Pip4.Withdraw(s.recipient, s.nullifierHash, 0, 0x2130ad5394b9ce6a2fa31b9127b857eef88b9ef6c0480004006a4c6f44cb2726);
        pip.withdraw(p, s); 

        // Cannot withdraw twice with the same proof.
        vm.expectRevert(abi.encodeWithSelector(Pip4.NullifierHashAlreadyUsed.selector));
        pip.withdraw(p, s); 

        // Cannot withdraw fees if you aren't the owner.
        vm.expectRevert();
        pip.withdrawFees();
        vm.stopPrank();

        assertEq(address(pip).balance, ownerFee, "sent withdrawal, only has fee left");
        assertEq(address(ALICE).balance, INITIAL_ETH - _denomination - GAS, "Depositor");
        assertEq(address(BOB).balance, INITIAL_ETH + withdrawalAmount + (GAS * 7500 / 10000), "Recipient");

        // withdraw fees
        vm.startPrank(OWNER);
        assertEq(address(OWNER).balance, INITIAL_ETH, "Before withdrawing fee");
        pip.withdrawFees();
        assertEq(pip.ownerFees(), 0, "All fees withdrawn");
        assertEq(address(OWNER).balance, INITIAL_ETH + ownerFee, "After withdrawing fee");
        assertEq(address(pip).balance, 0, "(deposit --> withdraw) full cycle");
        vm.stopPrank();
    }


    function testWithdrawERC20() public {

        uint256 _denomination = 100e18;
        uint256 totalFee = (_denomination * (OWNER_FEE + RELAYER_FEE)) / 10000;
        uint256 ownerFee = (_denomination * OWNER_FEE) / 10000;
        uint256 relayerFee = (_denomination * RELAYER_FEE) / 10000;
        uint256 withdrawalAmount = _denomination - totalFee;
        deployPool(false, _denomination, false);

        uint256 nullifier0 = createNullifier(bytes32(uint256(0)));
        //bytes32 nullifierHash0 = createNullifierHash(nullifier0, pip.leafIndex()); // leafIndex = 0
        bytes32 c0 = createCommitment(nullifier0);

        // DEPOSIT
        vm.startPrank(ALICE);
        token.approve(address(pip), INITIAL_TOKENS);
        pip.deposit{value: GAS}(c0);
        assertEq(address(pip).balance, GAS, "pip got deposit");
        assertEq(token.balanceOf(address(pip)), _denomination, "got deposit tokens");
        assertEq(token.balanceOf(ALICE), INITIAL_TOKENS - _denomination, "pip got deposit");
        vm.stopPrank();

        // Same proof as first ETH deposit in previous test.
        Pip4.ECPoints memory p;
        p.pA[0] = 0x27cf867ddb905666db1d1426ff2e375a7148e28d2c815d18c47749d1b08269eb;
        p.pA[1] = 0x1b66a6014d0abb0728262ab45d108c935cf5780d81916a90c74830b104b96c57;

        p.pB[0][0] = 0x2543004587c2d861261ffca9c667fed40fbf2ec4b87c53e1a67bf7e7c8387687;
        p.pB[0][1] = 0x2ebe2df0d725eb23e94a39900c683dd6baa1443d159a18cedb6f596ca128d69b;
        p.pB[1][0] = 0x0c37fd5c28dcd649acd6537b305b323447b2380d97972c923419e449479a52bb;
        p.pB[1][1] = 0x08fa91ea5924c9f7d8b54cb4c3c1a191ba50adc9dd94fbfd3a59d696b97bb27c;

        p.pC[0] = 0x2307be26a7efa628c744d04e026ad2e7bf68616a236f72839525b18e5019715e;
        p.pC[1] = 0x2761667d101b962096c13f6837d2e8b073a03850328b3a17a779d6eb0cd771a6;
        
        Pip4.PubSignals memory s;
        s.recipient = payable(BOB);
        s.root = 0x2130ad5394b9ce6a2fa31b9127b857eef88b9ef6c0480004006a4c6f44cb2726;
        s.nullifierHash = 0x02a48016be947d22695d63fbcb2f16964e4900062b6cc74351553b820a5bd1d0;

        vm.startPrank(RELAYER);
        pip.sendGas(p,s);
        vm.stopPrank();


        assertEq(address(BOB).balance, INITIAL_ETH + GAS * 7500 / 10000, "bob got gas");
        assertEq(address(RELAYER).balance, INITIAL_ETH + GAS * 2500 / 10000, "relayer got ETH fee");
        assertEq(token.balanceOf(RELAYER), relayerFee, "relayer got token fee");
        assertEq(address(pip).balance, 0, "pip has no ETH left, sent the gas");

        // Withdraw
        vm.startPrank(BOB);
        vm.expectEmit(true, true, true, true); // (to, nullifierHash, tree index, root)
        emit Pip4.Withdraw(s.recipient, s.nullifierHash, 0, 0x2130ad5394b9ce6a2fa31b9127b857eef88b9ef6c0480004006a4c6f44cb2726);
        pip.withdraw(p, s); 
        vm.stopPrank();

        assertEq(token.balanceOf(address(pip)), ownerFee, "sent tokens, just has fee left");

        assertEq(token.balanceOf(BOB), INITIAL_TOKENS + withdrawalAmount, "Recipient");


        // withdraw fees
        vm.startPrank(OWNER);
        pip.withdrawFees();
        assertEq(pip.ownerFees(), 0, "All fees withdrawn");
        assertEq(token.balanceOf(address(pip)), 0, "sent fee, no tokens left");
        assertEq(token.balanceOf(OWNER), ownerFee, "started with 0 tokens, now has fee");
        vm.stopPrank();
    }


    function testWithdrawManyETHDeposits() public {
        // Creates 3 and 1/2 full trees and withdraws some random leafs.

        uint256 _denomination = 1e18;
        uint256 _numDeposits = 56;
        uint256 _depositValue = _denomination + GAS;
        uint256 totalFee = (_denomination * (OWNER_FEE + RELAYER_FEE)) / 10000;
        uint256 ownerFee = (_denomination * OWNER_FEE) / 10000;
        uint256 relayerFee = (_denomination * RELAYER_FEE) / 10000;
        uint256 withdrawalAmount = _denomination - totalFee;
        deployPool(false, _denomination, true);

        bytes32[] memory roots = new bytes32[](_numDeposits);
        bytes32 depositEventSignature = keccak256("Deposit(bytes32,uint256,uint256,bytes32)");

        // 56 total deposits (32 from ALICE, 24 from BOB)
        for (uint256 i = 0; i < 56; i++) {
            uint256 treeIndex = i / 16;
            uint256 leafIndex = i % 16;

            uint256 nullifier = createNullifier(bytes32(uint256(i)));
            bytes32 nullifierHash = createNullifierHash(nullifier, leafIndex);
            bytes32 commitment = createCommitment(nullifier);

            vm.recordLogs();

            address depositor = (i < 32) ? ALICE : BOB;
            vm.startPrank(depositor);
            pip.deposit{value: _depositValue}(commitment);
            vm.stopPrank();

            Vm.Log[] memory logs = vm.getRecordedLogs();
            for (uint256 j = 0; j < logs.length; j++) {
                if (logs[j].topics[0] == depositEventSignature) {
                    roots[i] = bytes32(logs[j].topics[3]);
                    break;
                }
            }

            console.log("treeIndex:", treeIndex);
            console.log("nullifierHash", uint256(nullifierHash), "leafIndex", leafIndex);
            console.log("Root:", uint256(roots[i]), "leafIndex", leafIndex);
            console.log("nullifier", nullifier, "deposit index", i);
            console.log("commitment", uint256(commitment), "leafIndex", leafIndex);
        }


        assertEq(address(pip).balance, _numDeposits * _depositValue, "got all 56 deposits");
        assertEq(address(ALICE).balance, INITIAL_ETH - (32 * _depositValue), "depositor");
        assertEq(address(BOB).balance, INITIAL_ETH - (24 * _depositValue), "depositor");
        assertEq(pip.treeIndex(), _numDeposits / (2**HEIGHT), "4th tree (index 3)");
        assertEq(pip.leafIndex(), 8, "(56/16 = 3.5, 0.5*16 = 8)");

        // This data was generated from the console logs and building the tree with build-tree.js
        // Then did the input.json, generate witness, proof, and snarkjs generatecall.
        {
            // LEAF INDEX 6, TREE INDEX 0
            Pip4.ECPoints memory p60;
            p60.pA[0] = 0x2a3a4e1f6f455aa3804f68ef40077b56a9a3d3306ff0d1789dd76b0c3b793b8b;
            p60.pA[1] = 0x04accdcf7d08d76b27903a984702f21d9941facb1e0c41c445485c074dce91ff;

            p60.pB[0][0] = 0x2e7ee3b96d46a9df79aecfee591fcc21336f0c6b3062fd3aeec8656f50b91fe9;
            p60.pB[0][1] = 0x23b8818196918c44c5bc9fb8e0ef567e67db5bb0107c49e75440d4c9400506e1;
            p60.pB[1][0] = 0x0e941b3af2eec59a4d5c040a0beb68f8d7977a2f6374d1e17730eb3dfd8494b4;
            p60.pB[1][1] = 0x1083c6552c6de4db5f6ed01f69366410e163957b9698d1a884ca811f8356cfac;

            p60.pC[0] = 0x20d690b2562105e18ef9daf1fdeb9da94886a25397bfaa0bf5f1b864c42f3def;
            p60.pC[1] = 0x283565decc3ba69d1c3a6ec8a5a6ce6270d4739e26670e279520da547f93d2c9;
            
            Pip4.PubSignals memory s60;
            s60.recipient = payable(BOB);
            s60.nullifierHash = 0x2cbd8eb8fad8d073ae654fbf74e16ab243a53089ba03487dc8ad8c6ce7b103e6;
            s60.root = 0x1b1d512f686dfc33d10124b1d59a844ab8a4344267bd6a04678aad03ba1e890d;
            
            vm.startPrank(RELAYER);
            pip.sendGas(p60,s60);
            vm.stopPrank();

            vm.startPrank(BOB);
            pip.withdraw(p60,s60);
            vm.stopPrank();
            assertEq(address(pip).balance, (_numDeposits * _depositValue) - GAS - relayerFee - withdrawalAmount, "ye");

            // LEAF INDEX 11, TREE INDEX 0
            Pip4.ECPoints memory p110;
            p110.pA[0] = 0x25644f2a3414282258d98f89d7b70a75738ce10ac307031ed2de2d98675d7eaa;
            p110.pA[1] = 0x084aa6cf487d38d4d8cadec3d18d0503bc7063d6a51bc5a116fd1fed969cd2a3;

            p110.pB[0][0] = 0x018b08b473554c8b20f55591ebfbeafb3fcc0d29aa4dabbab3e8316419aea067;
            p110.pB[0][1] = 0x18d07cca18088cf9a2f3de0249c92efbdce0585ba86607ffb5932baf883adc85;
            p110.pB[1][0] = 0x1bcd03a22bae794c7e53346c28853e6b9a92c5592dc555103e019fed770fc4e7;
            p110.pB[1][1] = 0x20bcb5d558355e84014d9752b6f991815b60c5a5d3241bd989ec0def4fd5bf7d;

            p110.pC[0] = 0x04c2ad70fbe685fb8296eabc79e2ea7d2d5afb0dbd1fb2a37709a4e57488e6a0;
            p110.pC[1] = 0x1589b4c7efddb927cac1d021c3b41f8510934320d6241deef83cd9e2ccd65ee3;
            
            Pip4.PubSignals memory s110;
            s110.recipient = payable(BOB);
            s110.nullifierHash = 0x1c2fc73c932e580fee38b6f677372179af6023b1c19fc335eb7cdaf03121eaf2;
            s110.root = 0x1b1d512f686dfc33d10124b1d59a844ab8a4344267bd6a04678aad03ba1e890d;
            
            vm.startPrank(RELAYER);
            pip.sendGas(p110,s110);
            vm.stopPrank();

            vm.startPrank(BOB);
            pip.withdraw(p110,s110);
            vm.stopPrank();
            assertEq(address(pip).balance, (_numDeposits * _depositValue) - (2 * (GAS + relayerFee + withdrawalAmount)), "ye");

            // LEAF INDEX 0, TREE INDEX 1
            Pip4.ECPoints memory p01;
            p01.pA[0] = 0x1b3f41b5e316c2287b862a3321762ac91da837a040de26f91f65c0a7e9f10f62;
            p01.pA[1] = 0x0611b81de7d4eea3a71b216e709f75385dd4ce7019d1b5f52887ead2d4d7f5f1;

            p01.pB[0][0] = 0x02ae3b77fe0ac7fddff4e388e553884c0366e4fcb83c14ae8c80cb7cc70625b2;
            p01.pB[0][1] = 0x0986398aceeb07d952df7367970299e77f8d8a55e7142bc3feaf6eb54b9fb042;
            p01.pB[1][0] = 0x16e630a5a5836f4b16514fe897569bd4f1c26643048676e7e0935af45a962649;
            p01.pB[1][1] = 0x011830ef33a3309eb8bf821a9c13b61cddf52d13988722765454231b995548bf;

            p01.pC[0] = 0x287040e5a83dcf9d9b68371770f8b7ca8ad26bd5e13934e3b7b3f2380312cdaf;
            p01.pC[1] = 0x1aff232487a4d7a9bec10447825acc9e7868c41487a4e94c5945d5a814841a92;
            
            Pip4.PubSignals memory s01;
            s01.recipient = payable(BOB);
            s01.nullifierHash = 0x194732412d5ad6be5e7321528bad7da617e169022b650c7d8e3280253f3d3989;
            s01.root = 0x023175d472cbec9fef393f3d4e312b6f9541449bd541a6cbcd3cbe76f7fa7b99;
            
            vm.startPrank(RELAYER);
            pip.sendGas(p01,s01);
            vm.stopPrank();

            vm.startPrank(BOB);
            pip.withdraw(p01,s01);
            vm.stopPrank();

            // LEAF INDEX 15, TREE INDEX 1
            Pip4.ECPoints memory p151;
            p151.pA[0] = 0x1b2b6f4f2d79108714bf44819f9e3ff4a9cdd9fc0b58038c2074de0b30ca0625;
            p151.pA[1] = 0x0a2c837db81887d74b423435494e5823b659f429264b6da50643917362de0d0c;

            p151.pB[0][0] = 0x00ab059e0ae3a13a8b28c0af676cc65ab454c463c7c30173b7741ce0ec5a8199;
            p151.pB[0][1] = 0x2bcf4268f107c96054064de18493b157a7d6fb41851b1b1c24009af20b77e954;
            p151.pB[1][0] = 0x14267fac13887ebc989ae4a9c1002c09d44aa9dbeea7169c0f9a138aa9e7ac34;
            p151.pB[1][1] = 0x173bd1cd417e34faa0dfb60a3a79b26f63f246c29e2dddc1df5b3113e7bd8934;

            p151.pC[0] = 0x14735534f726220c10c0da800357f61a5c7db4f24743e0639646d689ac0b21be;
            p151.pC[1] = 0x126bfba5534b78f04134f8bb786e5144e242f98941e82ee5c06a7e2438420181;
            
            Pip4.PubSignals memory s151;
            s151.recipient = payable(BOB);
            s151.nullifierHash = 0x0daa4bb47a02715b56a4f6a29fb9d673f256c9bcf72fcdf63c8989d925dfa5bd;
            s151.root = 0x023175d472cbec9fef393f3d4e312b6f9541449bd541a6cbcd3cbe76f7fa7b99;
            
            vm.startPrank(RELAYER);
            pip.sendGas(p151,s151);
            vm.stopPrank();

            vm.startPrank(BOB);
            pip.withdraw(p151,s151);
            vm.stopPrank();

            // LEAF INDEX 4, TREE INDEX 2
            Pip4.ECPoints memory p42;
            p42.pA[0] = 0x2323b22de560b996a0529392cab005c7d3b2e5b5cbca8f9417bfe29165d77401;
            p42.pA[1] = 0x09536abc65ba76b1f9f200345ca43ac2c914a122d8a18fc1131f2787afd13e19;

            p42.pB[0][0] = 0x2928dbce0b0e1cac30d27f6285806910bb8da0cf239639b4b6c32455188089d9;
            p42.pB[0][1] = 0x269f4411a1a99a974b176081932af74b648edb39c26bd1f0929bcd7a14428225;
            p42.pB[1][0] = 0x1fb41c177b74e830bc87f71ea55d4a694a517346c9145ef20b15b781c42cc709;
            p42.pB[1][1] = 0x27fb9d9f9f4c6138e098ee943cd97260e9595d2e1eb4bf9576ccf76d34b2abb1;

            p42.pC[0] = 0x2ca5596d5e2ea729a44168cf65c77acccbc4e0a7f6bd686e698cfbcb4f41d071;
            p42.pC[1] = 0x07d13a83ac8019119b83cd4c75e5cd4659e93708a2d3e4fb0fb29f89c2d3be8c;
            
            Pip4.PubSignals memory s42;
            s42.recipient = payable(CHARLIE);
            s42.nullifierHash = 0x27d2a766d540580b04818f2d5f9bc6b9098834f6bb65efcf67ad172cc264cfd0;
            s42.root = 0x29f76f4f51cad50db597c49fac4fbaeafd43837e38a92c45a5a37a4c995eee27;
            
            vm.startPrank(RELAYER);
            pip.sendGas(p42,s42);
            vm.stopPrank();

            vm.startPrank(CHARLIE);
            pip.withdraw(p42,s42);
            vm.stopPrank();

            // LEAF INDEX 8, TREE INDEX 2
            Pip4.ECPoints memory p82;
            p82.pA[0] = 0x06abe91a5bbed6455ef73739c1bc3ec84ba5c78c58f785b52d3ac47e2b87a3ea;
            p82.pA[1] = 0x26b3c73eccc2f6e1cf438220b048a2eee5cbf21bfd33f3ce2377f3e90b6b4629;

            p82.pB[0][0] = 0x2b38d8d7a7990ccb00e2ca2b9493444a434ea65d14663358c098d8a23838dfe1;
            p82.pB[0][1] = 0x1c8753a49bac100c3c6b9acb105da47e9d6e09c9ac11810b1c67df0e5ebba139;
            p82.pB[1][0] = 0x169ef39242d7eefdee065597914d971eb1185891f96362a958bce2c081808fb2;
            p82.pB[1][1] = 0x24da3f46610e29c72fe9e134d84c7dea4689ef9d203c8725a853e531132d659a;

            p82.pC[0] = 0x042b6eddddbfc6fce01f181920003669b0b006f491ed048ad7a2ff04d0b15354;
            p82.pC[1] = 0x26b81f564f50028f4365ba181ff1a6c9122b42d3cad81a74669d3fab996c5a71;
            
            Pip4.PubSignals memory s82;
            s82.recipient = payable(CHARLIE);
            s82.nullifierHash = 0x1c3a005c941499a5fa08d27002dd5f23d740dcbb848ae4cd5fcaa098da39cbd9;
            s82.root = 0x29f76f4f51cad50db597c49fac4fbaeafd43837e38a92c45a5a37a4c995eee27;
            
            vm.startPrank(RELAYER);
            pip.sendGas(p82,s82);
            vm.stopPrank();

            vm.startPrank(CHARLIE);
            pip.withdraw(p82,s82);
            vm.stopPrank();

            // LEAF INDEX 1, TREE INDEX 3
            Pip4.ECPoints memory p13;
            p13.pA[0] = 0x07ba0ca49153060fff12419f1ebd5fa57de127c232a4205e0c163faf2a4fc482;
            p13.pA[1] = 0x2c60cbc75c254a4d3e6eb4e82a8bb49aecebf3c5bd53947b37b35d89aee2545b;

            p13.pB[0][0] = 0x0f66f54cdf0c47a2757606b66bf1b7abde9c3ae0631a5405ccecdd0e3ead9ad3;
            p13.pB[0][1] = 0x22a738d054725769877a05a07cfa0358c887b4c2b5f300e283d3a6008f43ddc3;
            p13.pB[1][0] = 0x259f416b1f4cd3c9f9cefbb5ee5c7fc446e8e505c7d6128909373569fe3279d4;
            p13.pB[1][1] = 0x1d1ea5a1bccd8fc960172b27437d6ce170ca11fd35555c7eee0bbb24a815f1cd;

            p13.pC[0] = 0x15b8ca58ae7a51324240876a95a24e53c0aa25cc68f692344b499a1d77a1d43c;
            p13.pC[1] = 0x0eb3bc053db6048e06f8d477e815343e044645370a89218446618199358b753c;
            
            Pip4.PubSignals memory s13;
            s13.recipient = payable(CHARLIE);
            s13.nullifierHash = 0x2cfe56beff6bb872735805bcf47985ba8283f23ded5bf4297929192e20fcec7a;
            s13.root = 0x1fd5b822c9dc1b52e1d34c8cae6dfc8146cad55e68bc78eb9b9f76ad2331de87;
            
            vm.startPrank(RELAYER);
            pip.sendGas(p13,s13);
            vm.stopPrank();

            vm.startPrank(CHARLIE);
            pip.withdraw(p13,s13);


            // LEAF INDEX 7, TREE INDEX 3
            Pip4.ECPoints memory p73;
            p73.pA[0] = 0x0e06f1ea698292f9c35979cdc59526ba87eeff7a7a562aa83841f63fd3ef005e;
            p73.pA[1] = 0x1bdb4b81a184671433975a6496f3aaf2735465e6962e1b3de2cfaad6d1dc145d;

            p73.pB[0][0] = 0x24502f216efccd7f89046e5984a6465083d9738c51140bf0212b7c3978ceca74;
            p73.pB[0][1] = 0x276c4cabe5e5adbdd01eb3494cccc9eba0ff27df359d0b6f97176f496253acfe;
            p73.pB[1][0] = 0x2c8dfdd391ca723ceab7a9beb5a934573fc07fde9987ddb47c5b79bd6e2efb73;
            p73.pB[1][1] = 0x2515d8cf792d6825adfe60987b5da2bad578663548e1dbab07de5ce76452bcbe;

            p73.pC[0] = 0x10c188389b2b760f0b21ee4ff8a34e85854aa1388f9b5f90d9654aa545bc497a;
            p73.pC[1] = 0x2e4155edfb2c58adf2e8fb44dd23cb679f86d9a1cbd08b44920d4cdac8d99a3c;
            
            Pip4.PubSignals memory s73;
            s73.recipient = payable(CHARLIE);
            s73.nullifierHash = 0x2d5c52f063aee4b72e80092ee0e7a6a2910b9efe5c36cac2527feb2d541cef53;
            s73.root = 0x1fd5b822c9dc1b52e1d34c8cae6dfc8146cad55e68bc78eb9b9f76ad2331de87;
            
            vm.startPrank(RELAYER);
            pip.sendGas(p73,s73);
            vm.stopPrank();

            vm.startPrank(CHARLIE);
            pip.withdraw(p73,s73);
            vm.stopPrank();
        }


        // 56 deposits, 8 withdrawals.

        // RELAYER
        assertEq(RELAYER.balance, INITIAL_ETH + (8 * (relayerFee + (GAS * 2500 / 10000))), "ye");

        // Charlie was a recipient of 4 withdraws from Bob, started with 0 ETH.
        assertEq(CHARLIE.balance, 4 * (withdrawalAmount + GAS * 7500 / 10000), "ok");

        // Bob was a depositor, but also a recipient in 4 of Alice's withdrawals.
        // Each withdraw = (withdrawAmount + GAS/2), relayer got the other part of the gas.
        assertEq(BOB.balance, INITIAL_ETH - (24 * _depositValue) + (4 * (withdrawalAmount + GAS * 7500 / 10000)), "k");

        assertEq(address(pip).balance, (_numDeposits * _depositValue) - (8 * (GAS + relayerFee + withdrawalAmount)), "ye");


        // OWNER withdrawals fees
        vm.startPrank(OWNER);
        assertEq(pip.ownerFees(), 8 * ownerFee, "8 fees accumulated");
        pip.withdrawFees();
        assertEq(OWNER.balance, INITIAL_ETH + 8 * ownerFee, "got fees");
        assertEq(address(pip).balance, ((_numDeposits - 8) * _depositValue), "Cleared of the 8 withdraws");
        vm.stopPrank();
    }


    function testChangeOwner() public {
        uint256 _denomination = 1e18;
        deployPool(false, _denomination, true);

        vm.startPrank(OWNER);

        pip.transferOwnership(RELAYER);
        vm.expectRevert();
        pip.withdrawFees();
        vm.stopPrank();

        vm.startPrank(RELAYER);

        pip.withdrawFees();
        pip.transferOwnership(BOB);
        vm.expectRevert();
        pip.withdrawFees();
        vm.stopPrank();

        vm.startPrank(BOB);
        
        pip.withdrawFees();
        pip.renounceOwnership();
        vm.expectRevert();
        pip.withdrawFees();
        vm.stopPrank();
    }
}