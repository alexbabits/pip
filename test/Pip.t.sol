// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Pip, IERC20, PoseidonT3, IGroth16Verifier} from "../src/Pip.sol"; 
import {SoloVerifier} from "../src/SoloVerifier.sol";
import {MockVerifier} from "./MockVerifier.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract PipTest is Test {

    address constant ALICE = address(0xA11C3); // uint256(uint160(ALICE)) = 659907
    address constant BOB = address(0xB0B); // uint256(uint160(BOB)) = 2827
    address constant CHARLIE = address(0xC); // 12
    address constant RELAYER = address(0x1337);
    address constant OWNER = address(0xDAD);

    uint256 constant INITIAL_ETH = 1000000e18;
    uint256 constant INITIAL_TOKENS = 1000000e18;
    
    uint256 public constant ZERO_VALUE = 11122724670666931127833274645309940916396779779585410472511079044548860378081; // Z0
    uint256 public constant Z1 = 1891682660472723078494341181381562966782342654802963640713393672196777141865; // (Z0.Z0)
    uint256 public constant Z2 = 11753225569593816999506130861675823105515818441245022216567454953943371433075; // (Z1.Z1)
    uint256 public constant Z3 = 21220542571259101805024786323770586210738494005346819350584272402182380114809; // (Z2.Z2)
    uint256 public constant Z4 = 8644737290680945076710588039446718562288487874374697375547992225316318271481; // ...
    uint256 public constant Z5 = 21280883860574621035190619787594670451741397277376882118887145813181318838392;
    uint256 public constant Z6 = 19610209818551322241200337909430942447770915265448627858564866621035908688038; 
    uint256 public constant Z7 = 3381213431567491831996692117453776422062595269695548941319004097621540592689;
    uint256 public constant Z8 = 14507494323055541897538738079996179114188727127228222146244135664968025502579; 
    uint256 public constant Z9 = 10855789681470844824326073611071855188032197533739032543496972808758164635844; 
    uint256 public constant Z10 = 821048615517369620721621298510361073256500646108995307324576437240228691504; 
    uint256 public constant Z11 = 10780519341849866963575553212368089745415993798949192957703616492151341153812;

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

    // Because `denomination` for all pools will have far more than just the last 4 digits being 0's, no rounding issues here.
    // The same goes for the GAS constant.

    function testDeployment() public {
        uint256 _denomination = 1e18;
        deployPool(false, _denomination, true);

        assertEq(pip.denomination(), _denomination, "should match");
        assertEq(address(pip.token()), address(0), "should be 0x0 for ETH");

        bytes32 Z0solidity = keccak256(abi.encodePacked("Pulse In Private"));
        bytes32 Z1solidity = pip.poseidonHash(Z0solidity, Z0solidity);
        bytes32 Z2solidity = pip.poseidonHash(Z1solidity, Z1solidity);
        bytes32 Z3solidity = pip.poseidonHash(Z2solidity, Z2solidity);
        bytes32 Z4solidity = pip.poseidonHash(Z3solidity, Z3solidity);
        bytes32 Z5solidity = pip.poseidonHash(Z4solidity, Z4solidity);
        bytes32 Z6solidity = pip.poseidonHash(Z5solidity, Z5solidity);
        bytes32 Z7solidity = pip.poseidonHash(Z6solidity, Z6solidity);
        bytes32 Z8solidity = pip.poseidonHash(Z7solidity, Z7solidity);
        bytes32 Z9solidity = pip.poseidonHash(Z8solidity, Z8solidity);
        bytes32 Z10solidity = pip.poseidonHash(Z9solidity, Z9solidity);
        bytes32 Z11solidity = pip.poseidonHash(Z10solidity, Z10solidity);

        bytes32[12] memory solidityPoseidon = [
            Z0solidity, 
            Z1solidity, 
            Z2solidity, 
            Z3solidity,
            Z4solidity,
            Z5solidity,
            Z6solidity,
            Z7solidity,
            Z8solidity,
            Z9solidity,
            Z10solidity,
            Z11solidity
        ];

        // generated from `../tree/build-tree.js`
        bytes32[12] memory jsPoseidon = [
            bytes32(0x18973d339bc06ed46f1d7aa1d8265b6688eaf583b4731e7c551c05c789dcfbe1),
            bytes32(0x042ea78997ff74a8d42c56cfdd623c85f4f1ce5df14610f4466be22faf5d6669),
            bytes32(0x19fc1705bb463e42aa596ab5f64c49bbf316112e97220b359a2901f12b4d4473),
            bytes32(0x2eea66c6432bae9767fd0791dbdc627320f6e971a4cc3861cb4f0d3e92aed379),
            bytes32(0x131CBF774BF4F97A33753EF1D820C91B41888CE8A05C399DA14AD31D9C58D7F9),
            bytes32(0x2F0C8DAD13BB8E22C1DDA40B6323256B61125111D617926E05FEEFF127503878),
            bytes32(0x2B5AFC44C09E38966DDF42C0262A0041167AFB66AFF529522F15F8A817C7E8A6),
            bytes32(0x0779B2F0925273F69FDA51054AE2D7ECA51970B3D80A8A2E2E57BF3E8015DC31),
            bytes32(0x2012F367BDCCB1E5C6BA65606C54B9AB80911F1723C5D8A0E851F652542FF373),
            bytes32(0x180028C2922068716C397C2DE387011DBC45E0873CEEEF4226A1281FEFEAC0C4),
            bytes32(0x01D0B271BF351CF62500D2EDC7D5ED0511C1389149FF2D22EF294EB7A2933E30),
            bytes32(0x17D58EC681025E3D0C4B597781FDF6FE5CC9CEB7DB98B208B6D93BD0973D7E14)
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
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.deposit{value: _denomination + GAS - 1}(c0);
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.deposit{value: _denomination + GAS + 1}(c0);
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.deposit{value: GAS}(c0);
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.deposit{value: 0}(c0);

        // FIRST DEPOSIT
        pip.deposit{value: _denomination + GAS}(c0);

        assertEq(address(pip).balance, _denomination + GAS, "should get deposit and gas");
        assertEq(ALICE.balance, INITIAL_ETH - _denomination - GAS, "should have paid denomination and gas");
        assertEq(pip.commitments(c0), true, "Deposit commitment should now exist in mapping");
        assertEq(pip.leafIndex(), 1, "should have incremented");

        // Cannot deposit again with same commitment
        vm.expectRevert(abi.encodeWithSelector(Pip.CommitmentAlreadyInTree.selector));
        pip.deposit{value: _denomination}(c0);
        

        // SECOND DEPOSIT
        uint256 nullifier1 = createNullifier(bytes32(uint256(6969)));
        bytes32 c1 = createCommitment(nullifier1);
        pip.deposit{value: _denomination + GAS}(c1);

        assertEq(address(pip).balance, 2 * (_denomination + GAS), "should get deposits and gas");
        assertEq(ALICE.balance, INITIAL_ETH - 2 * (_denomination + GAS), "should have paid denominations and gas");
        assertEq(pip.commitments(c1), true, "Deposit commitment should exist in mapping");
        assertEq(pip.leafIndex(), 2, "should have incremented");

        // 4094 more deposits (gas limit set to 10B in foundry toml). For 2^12 = 4096 full tree.
        for (uint256 i = 0; i < 4094; i++) {
            pip.deposit{value: _denomination + GAS}(createCommitment(createNullifier(bytes32(uint256(i)))));
        }

        assertEq(address(pip).balance, 4096 * (_denomination + GAS), "should get deposits and gas");
        assertEq(ALICE.balance, INITIAL_ETH - 4096 * (_denomination + GAS), "should have paid denominations and gas");
        assertEq(pip.leafIndex(), 4096, "should have incremented");

        vm.stopPrank();
      

        //                 /\
        //                /  \
        //               /    \
        //              /  #1  \
        //             /________\        /\  
        //                 ||           /__\     
        // O__/\_/\____O___||__/\__O__O__||____O___/\___

        vm.startPrank(BOB); // Change user to BOB

        // Next deposit creates new tree (c4096 = 4097th deposit, 0th indexing).
        bytes32 c4096 = createCommitment(createNullifier(bytes32(uint256(123456789))));
        pip.deposit{value: _denomination + GAS}(c4096);
        assertEq(address(pip).balance, 4097 * (_denomination + GAS), "should get deposits and gas");
        assertEq(BOB.balance, INITIAL_ETH - _denomination - GAS, "should have paid denomination and gas");

        assertEq(pip.treeIndex(), 1, "should have incremented");
        // (resets to 0 but during the 4097th deposit it increments it from 0 to 1
        // so we see theglobal  leaf index AFTER the first deposit of the new tree
        assertEq(pip.leafIndex(), 1, "should RESET back to 1");
        // C4096 is first deposit in new tree, which is the first sibling node after the deposit.
        assertEq(pip.siblingNodes(0), c4096, "should be C0");

        uint256 c0z0 = PoseidonT3.hash([uint256(c4096), uint256(pip.zeros(0))]);
        assertEq(uint256(pip.siblingNodes(1)), c0z0, "Should be reset to C0.Z0");

        uint256 c0z0z1 = PoseidonT3.hash([c0z0, uint256(pip.zeros(1))]);
        assertEq(uint256(pip.siblingNodes(2)), c0z0z1, "Should be reset to C0.Z0|Z1");

        uint256 c0z0z1z2 = PoseidonT3.hash([c0z0z1, uint256(pip.zeros(2))]);
        assertEq(uint256(pip.siblingNodes(3)), c0z0z1z2, "Should be reset to C0.Z0|Z1|Z2");

        uint256 c0z0z1z2z3 = PoseidonT3.hash([c0z0z1z2, uint256(pip.zeros(3))]);
        assertEq(uint256(pip.siblingNodes(4)), c0z0z1z2z3, "Should be reset to C0.Z0|Z1|Z2|Z3");
        // ... And so on...
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
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.deposit{value: GAS + 1}(commitment);
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.deposit{value: GAS - 1}(commitment);
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.deposit{value: 0}(commitment);
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.deposit{value: _denomination}(commitment);
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.deposit{value: _denomination + GAS}(commitment);

        // Deposit only successful with GAS value attached
        pip.deposit{value: GAS}(commitment);

        // 69 DEPOSITS LATER
        for (uint256 i = 0; i < 69; i++) {
            pip.deposit{value: GAS}(createCommitment(createNullifier(bytes32(uint256(i)))));
        }

        assertEq(address(pip).balance, 70 * GAS, "should got gas");
        assertEq(address(ALICE).balance, INITIAL_ETH - 70 * GAS, "should paid gas");
        assertEq(token.balanceOf(address(pip)), 70*_denomination, "should got tokens");
        assertEq(token.balanceOf(address(ALICE)), INITIAL_TOKENS - (_denomination*70), "should paid tokens");
        vm.stopPrank();
    }


    function testWithdrawETH() public {

        uint256 _denomination = 1e18;
        uint256 totalFee = (_denomination * (OWNER_FEE + RELAYER_FEE)) / 10000;
        uint256 ownerFee = (_denomination * OWNER_FEE) / 10000;
        uint256 relayerFee = (_denomination * RELAYER_FEE) / 10000;
        uint256 withdrawalAmount = _denomination - totalFee;
        deployPool(false, _denomination, true);

        uint256 nullifier0 = createNullifier(bytes32(uint256(0)));
        bytes32 nullifierHash0 = createNullifierHash(nullifier0, pip.leafIndex()); // leafIndex = 0
        bytes32 c0 = createCommitment(nullifier0);

        console.log("nullifier", nullifier0);
        console.log("nullifierHash", uint256(nullifierHash0));
        console.log("commitment", uint256(c0));

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

        Pip.ECPoints memory p;
        p.pA[0] = 0x0e9614c8c4844c55e36be0a74be2304824c13354a712b49509bf2c2296f1ea19;
        p.pA[1] = 0x23e7a2977394e5a46a6ce598f95f5ca2154a7e9cd1e1875cf740a0a75ead6983;

        p.pB[0][0] = 0x2270ab94dbdb71b5104a57718f0cc20ef91af5869a59adb43e2d498533658610;
        p.pB[0][1] = 0x1cdf8addc8523c8446b1ab9154718704eeab09ecd88131854364985644b182bb;
        p.pB[1][0] = 0x2fd6b1045c62c317c7dc74907485e3a06e8021d1b203fe358ad44f61ae45778d;
        p.pB[1][1] = 0x21cb682110ac41ed19d174da53db5305ed090c7ff87da90ba9221caae2576135;

        p.pC[0] = 0x0796ef325fc6c9acd62d038e0a03e720e77264b379c576fea863c58d4bad95b2;
        p.pC[1] = 0x2159d006b3b5656301126e8d2ca781f1fba3e447432e505c7d2809e39ea9d5f4;
        
        Pip.PubSignals memory s;
        s.recipient = payable(BOB);
        s.root = 0x2ebe2fa9b5deb26e596192200cd7ef3af29199905072e2137910e42501ebb003;
        s.nullifierHash = 0x02a48016be947d22695d63fbcb2f16964e4900062b6cc74351553b820a5bd1d0;

        // Proof is invalid if any bit of above data is incorrect

        // Pretend that BOB (recipient) is a fresh address that needs gas.
        // Relayer calls `sendGas()` on Bob's behalf.

        vm.startPrank(RELAYER);
        pip.sendGas(p,s);


        // Cannot claim gas twice with the same proof.
        vm.expectRevert(abi.encodeWithSelector(Pip.NullifierHashAlreadyUsed.selector));
        pip.sendGas(p, s); 

        vm.stopPrank();

        assertEq(address(BOB).balance, INITIAL_ETH + (GAS * 7500 / 10000), "bob got gas");
        assertEq(address(RELAYER).balance, INITIAL_ETH + relayerFee + (GAS * 2500 / 10000), "relayer got fees");
        assertEq(address(pip).balance, _denomination - relayerFee, "pip has denomination minus relayer fee");

        // Withdraw
        vm.startPrank(BOB);
        vm.expectEmit(true, true, true, true); // (to, nullifierHash, tree index, root)
        emit Pip.Withdraw(s.recipient, s.nullifierHash, 0, 0x2ebe2fa9b5deb26e596192200cd7ef3af29199905072e2137910e42501ebb003);
        pip.withdraw(p, s); 

        // Cannot withdraw twice with the same proof.
        vm.expectRevert(abi.encodeWithSelector(Pip.NullifierHashAlreadyUsed.selector));
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
        bytes32 nullifierHash0 = createNullifierHash(nullifier0, pip.leafIndex()); // leafIndex = 0
        bytes32 c0 = createCommitment(nullifier0);

        console.log("nullifier", nullifier0);
        console.log("nullifierHash", uint256(nullifierHash0));
        console.log("commitment", uint256(c0));

        // DEPOSIT
        vm.startPrank(ALICE);
        token.approve(address(pip), INITIAL_TOKENS);
        pip.deposit{value: GAS}(c0);
        assertEq(address(pip).balance, GAS, "pip got deposit");
        assertEq(token.balanceOf(address(pip)), _denomination, "got deposit tokens");
        assertEq(token.balanceOf(ALICE), INITIAL_TOKENS - _denomination, "pip got deposit");
        vm.stopPrank();

        // Same proof as first ETH deposit in previous test (since using same nullifier/commitment for simplicity)
        Pip.ECPoints memory p;
        p.pA[0] = 0x0e9614c8c4844c55e36be0a74be2304824c13354a712b49509bf2c2296f1ea19;
        p.pA[1] = 0x23e7a2977394e5a46a6ce598f95f5ca2154a7e9cd1e1875cf740a0a75ead6983;

        p.pB[0][0] = 0x2270ab94dbdb71b5104a57718f0cc20ef91af5869a59adb43e2d498533658610;
        p.pB[0][1] = 0x1cdf8addc8523c8446b1ab9154718704eeab09ecd88131854364985644b182bb;
        p.pB[1][0] = 0x2fd6b1045c62c317c7dc74907485e3a06e8021d1b203fe358ad44f61ae45778d;
        p.pB[1][1] = 0x21cb682110ac41ed19d174da53db5305ed090c7ff87da90ba9221caae2576135;

        p.pC[0] = 0x0796ef325fc6c9acd62d038e0a03e720e77264b379c576fea863c58d4bad95b2;
        p.pC[1] = 0x2159d006b3b5656301126e8d2ca781f1fba3e447432e505c7d2809e39ea9d5f4;
        
        Pip.PubSignals memory s;
        s.recipient = payable(BOB);
        s.root = 0x2ebe2fa9b5deb26e596192200cd7ef3af29199905072e2137910e42501ebb003;
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
        emit Pip.Withdraw(s.recipient, s.nullifierHash, 0, 0x2ebe2fa9b5deb26e596192200cd7ef3af29199905072e2137910e42501ebb003);
        pip.withdraw(p, s); 
        vm.stopPrank();

        assertEq(token.balanceOf(address(pip)), ownerFee, "sent tokens, just has fee left");
        assertEq(token.balanceOf(BOB), INITIAL_TOKENS + withdrawalAmount, "Recipient");

        // Withdraw fees
        vm.startPrank(OWNER);
        pip.withdrawFees();
        assertEq(pip.ownerFees(), 0, "All fees withdrawn");
        assertEq(token.balanceOf(address(pip)), 0, "sent fee, no tokens left");
        assertEq(token.balanceOf(OWNER), ownerFee, "started with 0 tokens, now has fee");
        vm.stopPrank();
    }


    function testEthPoolBalancePermutations() public pure {

        uint256 _denomination = 1e18;
        uint256 totalFee = (_denomination * (OWNER_FEE + RELAYER_FEE)) / 10000;
        uint256 ownerFee = (_denomination * OWNER_FEE) / 10000;
        uint256 relayerFee = (_denomination * RELAYER_FEE) / 10000;

        uint256 depositAmount = _denomination + GAS;
        uint256 withdrawAmount = _denomination - totalFee;
        uint256 sendGasAmount = relayerFee + GAS;

        // Permutations for a full lifecycle:
        // 1. Deposit must come first
        // 2. OwnerWithdrawFees must come after Withdraw
        // 3. withdrawCount & sendGasCount are LTE depositCount

        // Deposit, Withdraw, SendGas, OwnerWithdrawFees = 0
        // Deposit, Withdraw, OwnerWithdrawFees, SendGas = 0
        // Deposit, SendGas, Withdraw, OwnerWithdrawFees = 0

        // d = depositCount, w = withdrawConut, g = sendGasCount, DEN = denomination

        // When d = w = g
        // 0 = (d * depositAmount) - (w * withdrawAmount) - (g * sendGasAmount) - (w * ownerFee)

        // When d != w, and d != g
        // (d-d)*depositAmount + (d-w)*withdrawAmount + (d-g)*sendGasAmount + (d-w)*ownerFee =
        // (d * depositAmount) - (w * withdrawAmount) - (g * sendGasAmount) - (w * ownerFee)

        // Example with 69 deposits, 69 withdraws, 69 sendGas, and owner withdraws fees:
        // (69 * (1e18 + 1e14)) - (69 * (1e18 - (0.0025 * 1e18))) - (69 * ((0.0005 * 1e18) + 1e14)) - (69 * 0.002 * 1e18) = 0 // TRUE

        // Example with 69 deposits, 52 withdraws, 37 sendGas, and owner withdraws fees:
        // There should be 17 withdraw values left, 32 sendGas values left, and 52 ownerFees left.
        // (69 * (1e18 + 1e14)) - (52 * (1e18 - (0.0025 * 1e18))) - (37 * ((0.0005 * 1e18) + 1e14)) - (52 * 0.002 * 1e18) = 1.70107e19
        // (17 * (1e18 - (0.0025 * 1e18))) + (32 * ((0.0005 * 1e18) + 1e14)) + (17 * 0.002 * 1e18) = 1.70107e19

        // For a single deposit lifecycle: (depositCount = withdrawCount = sendGasCount = 1)

        // {Deposit}
        assertEq(depositAmount, sendGasAmount + withdrawAmount + ownerFee, "ok"); 
        //(1e18 + 1e14) = ((0.0005 * 1e18) + 1e14) + (1e18 - (0.0025*1e18)) + (0.002 * 1e18) // (1.0001e18 = 1.0001e18)

        // {Deposit, SendGas}
        assertEq(depositAmount - sendGasAmount, withdrawAmount + ownerFee, "ok");
        //(1e18 + 1e14) - ((0.0005 * 1e18) + 1e14) = (1e18 - (0.0025*1e18)) + (0.002 * 1e18) // True (9.995e17 = 9.995e17)

        // {Deposit, Withdraw}
        assertEq(depositAmount - withdrawAmount, sendGasAmount + ownerFee, "ok");
        //(1e18 + 1e14) - (1e18 - (0.0025*1e18)) = ((0.0005 * 1e18) + 1e14) + (0.002 * 1e18) // True (2.6e15 = 2.6e15)

        // {Deposit, SendGas, Withdraw}
        assertEq(depositAmount - sendGasAmount - withdrawAmount, ownerFee, "ok");
        //(1e18 + 1e14) - ((0.0005 * 1e18) + 1e14) - (1e18 - (0.0025*1e18)) = (0.002 * 1e18) // True (2e15 = 2e15)

        // {Deposit, Withdraw, SendGas}
        assertEq(depositAmount - withdrawAmount - sendGasAmount, ownerFee, "ok");
        //(1e18 + 1e14) - (1e18 - (0.0025*1e18)) - ((0.0005 * 1e18) + 1e14) = (0.002 * 1e18) // True (2e15 = 2e15)

        // {Deposit, SendGas, Withdraw, OwnerWithdrawFee}
        assertEq(depositAmount - sendGasAmount - withdrawAmount - ownerFee, 0, "ok");
        //(1e18 + 1e14) - ((0.0005 * 1e18) + 1e14) - (1e18 - (0.0025*1e18)) - (0.002 * 1e18) = 0 // True

        // {Deposit, Withdraw, SendGas, OwnerWithdrawFee}
        assertEq(depositAmount - withdrawAmount - sendGasAmount - ownerFee, 0, "ok"); // 0=0 permutation of above

        // {Deposit, Withdraw, OwnerWithdawFee, SendGas}
        assertEq(depositAmount - withdrawAmount - ownerFee - sendGasAmount, 0, "ok"); // 0=0 permutation of above
    }


    function testERC20PoolBalancePermutations() public pure {
        
        uint256 _denomination = 1e18;
        uint256 totalFee = (_denomination * (OWNER_FEE + RELAYER_FEE)) / 10000;
        uint256 ownerFee = (_denomination * OWNER_FEE) / 10000;
        uint256 relayerFee = (_denomination * RELAYER_FEE) / 10000;

        uint256 depositAmountERC20 = _denomination;
        uint256 depositAmountETH = GAS;
        uint256 withdrawAmount = _denomination - totalFee;
        uint256 sendGasAmountERC20 = relayerFee;
        uint256 sendGasAmountETH = GAS;


        // {Deposit} (ERC20 balances)
        assertEq(depositAmountERC20, sendGasAmountERC20 + withdrawAmount + ownerFee, "ok");

        // {Deposit} (ETH balances)
        assertEq(depositAmountETH, sendGasAmountETH, "ok");

        // {Deposit, SendGas} (ERC20 balances)
        assertEq(depositAmountERC20 - sendGasAmountERC20, withdrawAmount + ownerFee, "ok");

        // {Deposit, SendGas} (ETH balances)
        assertEq(depositAmountETH - sendGasAmountETH, 0, "ok");

        // {Deposit, Withdraw} (ERC20 balances)
        assertEq(depositAmountERC20 - withdrawAmount, sendGasAmountERC20 + ownerFee, "ok");

        // {Deposit, Withdraw} (ETH balances)
        // Withdraw has no effect on ETH balances

        // {Deposit, SendGas, Withdraw} (ERC20 balances)
        assertEq(depositAmountERC20 - sendGasAmountERC20 - withdrawAmount, ownerFee, "ok");

        // {Deposit, SendGas, Withdraw} (ETH balances)
        assertEq(depositAmountETH - sendGasAmountETH, 0, "ok");

        // {Deposit, SendGas, Withdraw, OwnerWithdrawFee} (ERC20 balances)
        assertEq(depositAmountERC20 - sendGasAmountERC20 - withdrawAmount - ownerFee, 0, "ok");

        // {Deposit, SendGas, Withdraw, OWnerWithdrawFee} (ETH balances)
        assertEq(depositAmountETH - sendGasAmountETH, 0, "ok");

        // No need to retest redundant permutations because already done in ETH pool test.
    }

}