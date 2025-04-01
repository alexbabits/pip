// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Pip, IERC20, PoseidonT3, IPlonkVerifierPPOT} from "../src/Pip.sol"; 
import {PlonkVerifierPPOT} from "../src/PlonkVerifierPPOT.sol";
import {MockVerifier} from "./MockVerifier.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract PipTest is Test {

    address constant ALICE = address(0xA11C3); // uint256(uint160(ALICE)) = 659907
    address constant BOB = address(0xB0B); // uint256(uint160(BOB)) = 2827
    address constant CHARLIE = address(0xC); // 12
    address constant RELAYER = address(0x1337);
    address constant OWNER = address(0xDAD);

    uint256 constant INITIAL_ETH = 1000000e18; // 1M
    uint256 constant INITIAL_TOKENS = 1000000e18; // 1M
    
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

    Pip public pip;
    IPlonkVerifierPPOT public verifier;
    IPlonkVerifierPPOT public mockVerifier;
    ERC20Mock public token;


    function setUp() public {
        verifier = IPlonkVerifierPPOT(address(new PlonkVerifierPPOT()));
        mockVerifier = IPlonkVerifierPPOT(address(new MockVerifier()));
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

    // Because `denomination` for all pools will have far more than just the last 4 digits being 0's, 
    // No rounding issues when calculation relayer or owner fee, even if relayerFee = 1 (0.01%).

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


    // Notice:THIS FUNCTION DOES OVER 4000 DEPOSITS AND TAKES ~13 seconds to run.
    // Notice: Average deposit gas cost: ~1,950,389,689 / 4097 = ~476,000 GAS.
    // Notice: First deposit will cost ~240,000 more GAS for around 700,000 total GAS, because it's setting all 12 sibling node values.
    // Notice: Deposits that update more sibling nodes will use more gas.
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

        // Cannot deposit amount other than (_denomination)
        uint256 nullifier = createNullifier(bytes32(uint256(69420)));
        bytes32 c0 = createCommitment(nullifier);
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.deposit{value: _denomination - 1}(c0);
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.deposit{value: _denomination + 1}(c0);
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.deposit{value: 69}(c0);
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.deposit{value: 0}(c0);

        // FIRST DEPOSIT
        pip.deposit{value: _denomination}(c0);

        assertEq(address(pip).balance, _denomination, "should get deposit");
        assertEq(ALICE.balance, INITIAL_ETH - _denomination, "should have paid denomination");
        assertEq(pip.commitments(c0), true, "Deposit commitment should now exist in mapping");
        assertEq(pip.leafIndex(), 1, "should have incremented");

        // Cannot deposit again with same commitment
        vm.expectRevert(abi.encodeWithSelector(Pip.CommitmentAlreadyInTree.selector));
        pip.deposit{value: _denomination}(c0);


        // SECOND DEPOSIT
        uint256 nullifier1 = createNullifier(bytes32(uint256(6969)));
        bytes32 c1 = createCommitment(nullifier1);
        pip.deposit{value: _denomination}(c1);

        assertEq(address(pip).balance, 2 * _denomination, "should get deposits");
        assertEq(ALICE.balance, INITIAL_ETH - (2 * _denomination), "should have paid denominations");
        assertEq(pip.commitments(c1), true, "Deposit commitment should exist in mapping");
        assertEq(pip.leafIndex(), 2, "should have incremented");

        // 4094 more deposits (gas limit set to 10B in foundry toml). For 2^12 = 4096 full tree.
        for (uint256 i = 0; i < 4094; i++) {
            pip.deposit{value: _denomination}(createCommitment(createNullifier(bytes32(uint256(i)))));
        }

        assertEq(address(pip).balance, 4096 * _denomination, "should get deposits");
        assertEq(ALICE.balance, INITIAL_ETH - (4096 * _denomination), "should have paid denominations");
        // Notice this is after the final deposit, the tree's leaf indices are 0 to 4095.
        // This 4096 index doesn't really "exist" and will be incremented back to 0 for the next tree deposit
        // and then after the first deposit of this new tree, it will increment from 0 to 1.
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
        pip.deposit{value: _denomination}(c4096);
        assertEq(address(pip).balance, 4097 * _denomination, "should get deposits");
        assertEq(BOB.balance, INITIAL_ETH - _denomination, "should have paid denomination");

        assertEq(pip.treeIndex(), 1, "should have incremented");
        // (resets to 0 but during the 4097th deposit it increments it from 0 to 1
        // so we see the global leaf index AFTER the first deposit of the new tree
        // The first deposit of the new tree is properly linked to leafIndex 0 via the `Deposit` event emitting `leafIndex - 1`
        assertEq(pip.leafIndex(), 1, "should RESET back to 1 after first deposit completes");

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

        // Cannot deposit with any value
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.deposit{value: 1}(commitment);

        // Deposit only successful with no value attached
        pip.deposit(commitment);

        // 69 DEPOSITS LATER
        for (uint256 i = 0; i < 69; i++) {
            pip.deposit(createCommitment(createNullifier(bytes32(uint256(i)))));
        }

        assertEq(address(pip).balance, 0, "no value given");
        assertEq(address(ALICE).balance, INITIAL_ETH, "no value given");
        assertEq(token.balanceOf(address(pip)), 70*_denomination, "should got tokens");
        assertEq(token.balanceOf(address(ALICE)), INITIAL_TOKENS - (_denomination*70), "should paid tokens");
        vm.stopPrank();
    }


    // Withdraw = ~369,000 GAS for native tokens with relayer call
    function testRelayerWithdrawETH() public {

        uint256 _denomination = 1e18;
        uint256 _relayerFee = 30; // 0.30% in this example
        uint256 gas = 1e16; // 0.01 ETH in this example

        uint256 ownerFee = _denomination * OWNER_FEE / 10000;
        uint256 relayerFee = _denomination * _relayerFee / 10000;
        uint256 totalFee = ownerFee + relayerFee;
        uint256 withdrawAmount = _denomination - totalFee;
        deployPool(false, _denomination, true);

        uint256 nullifier0 = createNullifier(bytes32(uint256(0)));
        bytes32 nullifierHash0 = createNullifierHash(nullifier0, pip.leafIndex()); // leafIndex = 0
        bytes32 c0 = createCommitment(nullifier0);

        console.log("nullifier", nullifier0);
        console.log("nullifierHash", uint256(nullifierHash0));
        console.log("commitment", uint256(c0));

        // DEPOSIT
        vm.startPrank(ALICE);
        pip.deposit{value: _denomination}(c0);
        assertEq(address(pip).balance, _denomination, "pip got deposit");
        vm.stopPrank();

        // Data generated from `snarkjs generatecall`. circom2 docs: https://docs.circom.io/getting-started/
        // Create an `input.json` that satisfies the circuit. Create witness. Generate proof.

        // {recipient, root, nullifier, nullifierHash, pathElements, pathIndices}
        // root: Can be found by building the latest tree in build-tree.js, or looking at Deposit event.
        // nullifier & nullifierHash: console.log
        // pathElements: Found in build-tree.js (first deposit is just Z0, Z1, Z2, Z3)
        // pathIndices: The binary representation of the leafIndex.

        uint256[24] memory p = [
            uint256(0x0ed1e923f9f106f7f834b597339480eee13f4fd75e892744453ba559c507febc),
            uint256(0x109ccf0c7016194d2fa9591aef7c9307ff5b25afb5db756874648c5007e16782),
            uint256(0x1de45dee073b2b1073758c3403bc8754c3e504928e78f3021e4ef700de9ea6be),
            uint256(0x16b91368250c89838ed48d4201b095c5fbaa770b429ff62d21801c1641f54c8d),
            uint256(0x1d1c50c3a040dab83b7c4c400ee303173bd1bcfcddad0966fee814d3fe980b80),
            uint256(0x0e42298d023ab2476a30bae89a1c8a80d4a44d14fa877ec7cea4f319fc7204df),
            uint256(0x205797d0f7bd2216380ac64dd996196d448cd5f1cff557853b42e1be495f37ad),
            uint256(0x00aea37039021da7fcc4f71763edfbef026941453bca796d671b20635179866d),
            uint256(0x16db862a5be1da5d185226b0ee12776b962fa9d5c722b07919a9f5e140f379ca),
            uint256(0x19e870ef007b1ed68e481490a6148cf372e0d39b6212290f451b97c2153531db),
            uint256(0x015da5218c940be95ff3aae043ce260a12e022582a0f4a5d687a4fc9ccbcd28e),
            uint256(0x2c3ca3e9b35baa7dcc08bb3c83ac54e41d4c0177922d71356505230014fabb40),
            uint256(0x2e45b87598469c5d854c7c8983f436a5a5fe6d168182be1e4cb880eb13f439a6),
            uint256(0x294bf0bbc33101d07fe8bf71e38f5127de9ce8101a249e76f406f23cf156fd37),
            uint256(0x207b4e8ba52ac072e64e41cea6b69cdd1a312a1134f2d579306c55134acc098e),
            uint256(0x190624eb6559a03372789314c1caadf319809d4b37691e744600c44e28bacba6),
            uint256(0x2e02dc7033dd55fa91f6bf1ca4a101cf5ae78f0ab1424bd934f85c38b787c171),
            uint256(0x0f05f7d7251b5319a6bc7e1475340504defd4fcc57ec76c9a093ded4a7d59618),
            uint256(0x1ba55ec0406c2e38d67b7811a45098cee5fb46a0e5c4524a974c4cec80ea1e17),
            uint256(0x212cb82d77a7876e00a767553206da2f309ef466fffc7b200bb65ee7b8a7aeaf),
            uint256(0x21dc18cf953c649235501d86806cb509e74e8f6d6a001347f5cb527491313ec3),
            uint256(0x21ab387c53fa47de14ad9b15bee23807e208a4adc02f87d3c4e68bf320c2f4a1),
            uint256(0x2e10e71c283ab704301c84ff421e003dc602e53557746b98805b86de00b3b995),
            uint256(0x1b8149a3e659d1d5a71ea4b3655e5970d3c80370413255f4c5ef54e615b51b03)
        ];
    
        Pip.PubSignals memory s;
        s.recipient = payable(BOB);
        s.gas = gas;
        s.fee = _relayerFee;
        s.root = 0x2ebe2fa9b5deb26e596192200cd7ef3af29199905072e2137910e42501ebb003;
        s.nullifierHash = 0x02a48016be947d22695d63fbcb2f16964e4900062b6cc74351553b820a5bd1d0;

        // Proof is invalid if any bit of above data is incorrect

        // Withdraw
        vm.startPrank(RELAYER);

        // Cannot send wrong value amounts
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.withdraw{ value: gas+1}(p, s); 
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.withdraw{ value: gas-1}(p, s); 
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.withdraw{ value: 0}(p, s); 

        vm.expectEmit(true, true, true, true); // (to, nullifierHash, tree index, root)
        emit Pip.Withdraw(s.recipient, s.nullifierHash, 0, 0x2ebe2fa9b5deb26e596192200cd7ef3af29199905072e2137910e42501ebb003);
        pip.withdraw{ value: gas}(p, s); 

        // Cannot withdraw twice with the same proof. (nullifierHash is used)
        vm.expectRevert(abi.encodeWithSelector(Pip.ProofInvalidOrUsed.selector));
        pip.withdraw{ value: gas}(p, s); 

        vm.stopPrank();

        // Cannot withdraw fees if you aren't the owner.
        vm.expectRevert();
        pip.withdrawFees();
        vm.stopPrank();

        assertEq(address(pip).balance, ownerFee, "sent withdrawal, only has owners fee left");
        assertEq(address(ALICE).balance, INITIAL_ETH - _denomination, "Depositor gave denominatino");
        assertEq(address(BOB).balance, INITIAL_ETH + withdrawAmount + gas, "Recipient got withdraw and gas");
        assertEq(address(RELAYER).balance, INITIAL_ETH - gas + relayerFee, "relayer gave gas and got relayerFee");

        // withdraw fees
        vm.startPrank(OWNER);
        assertEq(address(OWNER).balance, INITIAL_ETH, "Before withdrawing fee");
        pip.withdrawFees();
        assertEq(pip.ownerFees(), 0, "All fees withdrawn");
        assertEq(address(OWNER).balance, INITIAL_ETH + ownerFee, "After withdrawing fee");
        assertEq(address(pip).balance, 0, "(deposit --> withdraw) full cycle");

        vm.stopPrank();
    }


    // Withdraw = ~359,000 GAS for native tokens no relayer call
    function testUserWithdrawETH() public {
        uint256 _denomination = 1e18;
        uint256 _relayerFee = 0; 
        uint256 gas = 0;

        uint256 ownerFee = _denomination * OWNER_FEE / 10000;
        uint256 relayerFee = _denomination * _relayerFee / 10000;
        uint256 totalFee = ownerFee + relayerFee;
        uint256 withdrawAmount = _denomination - totalFee;
        deployPool(false, _denomination, true);

        uint256 nullifier0 = createNullifier(bytes32(uint256(0)));
        bytes32 nullifierHash0 = createNullifierHash(nullifier0, pip.leafIndex()); // leafIndex = 0
        bytes32 c0 = createCommitment(nullifier0);

        console.log("nullifier", nullifier0);
        console.log("nullifierHash", uint256(nullifierHash0));
        console.log("commitment", uint256(c0));

        // DEPOSIT
        vm.startPrank(ALICE);
        pip.deposit{value: _denomination}(c0);
        assertEq(address(pip).balance, _denomination, "pip got deposit");
        vm.stopPrank();

        uint256[24] memory p = [
            uint256(0x2cda3043edcf91844be6e8be65e29a6a84b809e310e2c441336b0e9c255d1045),
            uint256(0x275931589ec68ad4da3da0a93d63ad6bc1d8fc71b944f6c0bc656084b247daaa),
            uint256(0x03473bc0b46331b1dcfef263784209f65391471361c41611ef644a4b63d9d285),
            uint256(0x11cfcaf117335fa8906eadf0c60b263e3db9e57166037a2c422ddbdb0ca5e7ef),
            uint256(0x141ccd687c66a4e9a95fda3cf3ab079a727488b4288bd3d8513d79f2f0bf652c),
            uint256(0x300e5d69e1a26809fe9b78a1402603581773b148ba1dd3f63707c99309e54caf),
            uint256(0x13385c31b8a1b9e9d5bf46a00c5a7fe4201d1cb22e0bb9b7444087c55aad024f),
            uint256(0x2d2a260eefa40b12a2f30541a4ddfcf32b27686821946acb9d358c9fb7c9e902),
            uint256(0x19a4f73dfedc0836957d2d4d22815faaf2d95f4e0bdd4abe4f05fbd296524c26),
            uint256(0x27ed193598e778d2f909916c479242bd0eb291b5b7fb8e2724f1605f78b0448b),
            uint256(0x17c7fe99fbb0134cff24bde06cc08efd2a5db7a83930e5dfc3c6e3fb30907027),
            uint256(0x1470772928d11a4e05c23fecccf641b2427836162ab482197bd4ea48a4854d12),
            uint256(0x046b0c07d4d2e445b3eddfbfa12d4243d4d6bf692bf05fa8bbe1da4d7d306fec),
            uint256(0x1c177da23ff2696a340a6ac1f8ad42de7afb152faaa087f58134d5d130d9b88f),
            uint256(0x05040cfe171a0e0729f5c8015a7836eb5316384c02235963f7d14bb61bbde20d),
            uint256(0x1c90469b36056d358743665510d1faa2765548215f2645218676a24e05b10ce4),
            uint256(0x0619223e599ef2d4e2ef777e7a8a7b6facdea7a6b1b3b54fb28a5e7d04ed70b4),
            uint256(0x2a38fa2f09afc6e1195339157bb50c0e8e419800e91e90b8eeefb48315e48080),
            uint256(0x05a30b41e17c948fb925811c69babb1f41ddb939d9bf31c1c560da20b84001db),
            uint256(0x0d37e0ea090481ed9a95166337be766a6999260fe9ee7b64bacbd77ed0e9571c),
            uint256(0x291de38db51d60d2de9e1afd1d71f857b704d52e437f56d5b432b3c90d79c7b4),
            uint256(0x1feb7cf3676c3090de882a5b84b742f453aefd49a63f0293a0930578cda13aad),
            uint256(0x0f80402da3aec3732578a67b9507b714c5a520693d343006ee5cd51adc7683e8),
            uint256(0x25564497078437060e77cfc16092dfce1d0a27f019eac92f1a2911f54dfda0b9)
        ];
    
        Pip.PubSignals memory s;
        s.recipient = payable(BOB);
        s.gas = gas;
        s.fee = _relayerFee;
        s.root = 0x2ebe2fa9b5deb26e596192200cd7ef3af29199905072e2137910e42501ebb003;
        s.nullifierHash = 0x02a48016be947d22695d63fbcb2f16964e4900062b6cc74351553b820a5bd1d0;

        // Proof is invalid if any bit of above data is incorrect

        // Withdraw (BOB wants to withdraw himself, no relayer)
        vm.startPrank(BOB);

        // Cannot send any gas if s.gas is 0.
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.withdraw{ value: 1}(p, s); 

        vm.expectEmit(true, true, true, true); // (to, nullifierHash, tree index, root)
        emit Pip.Withdraw(s.recipient, s.nullifierHash, 0, 0x2ebe2fa9b5deb26e596192200cd7ef3af29199905072e2137910e42501ebb003);
        pip.withdraw(p, s); 

        // Cannot withdraw twice with the same proof. (nullifierHash is used)
        vm.expectRevert(abi.encodeWithSelector(Pip.ProofInvalidOrUsed.selector));
        pip.withdraw(p, s); 

        vm.stopPrank();

        assertEq(address(pip).balance, ownerFee, "sent withdrawal, only has owners fee left");
        assertEq(address(ALICE).balance, INITIAL_ETH - _denomination, "Depositor gave denominatino");
        assertEq(address(BOB).balance, INITIAL_ETH + withdrawAmount, "Recipient got withdraw");

        // withdraw fees
        vm.startPrank(OWNER);
        assertEq(address(OWNER).balance, INITIAL_ETH, "Before withdrawing fee");
        pip.withdrawFees();
        assertEq(pip.ownerFees(), 0, "All fees withdrawn");
        assertEq(address(OWNER).balance, INITIAL_ETH + ownerFee, "After withdrawing fee");
        assertEq(address(pip).balance, 0, "(deposit --> withdraw) full cycle");

        vm.stopPrank();
    }


    // ERC20 withdraws gas = ~403,000 with relayer
    function testRelayerWithdrawERC20() public {
        uint256 _denomination = 100e18;
        uint256 _relayerFee = 30; // 0.30% in this example
        uint256 gas = 1e16; // 0.01 ETH in this example

        uint256 ownerFee = _denomination * OWNER_FEE / 10000;
        uint256 relayerFee = _denomination * _relayerFee / 10000;
        uint256 totalFee = ownerFee + relayerFee;
        uint256 withdrawAmount = _denomination - totalFee;
        deployPool(false, _denomination, false);

        uint256 nullifier0 = createNullifier(bytes32(uint256(0)));
        //bytes32 nullifierHash0 = createNullifierHash(nullifier0, pip.leafIndex()); // leafIndex = 0
        bytes32 c0 = createCommitment(nullifier0);

        // DEPOSIT
        vm.startPrank(ALICE);
        token.approve(address(pip), _denomination); // Can also just approve denomination only.
        pip.deposit(c0);
        assertEq(address(pip).balance, 0, "pip got no native tokens");
        assertEq(token.balanceOf(address(pip)), _denomination, "pip got deposit");
        vm.stopPrank();

        // can be lazy and use same proof values as the Relayer ETH withdraw
        // Because we used all the same data for the witness generation
        // In reality, obviously all `nullifierHash` will be unique for each deposit/proof.
        uint256[24] memory p = [
            uint256(0x0ed1e923f9f106f7f834b597339480eee13f4fd75e892744453ba559c507febc),
            uint256(0x109ccf0c7016194d2fa9591aef7c9307ff5b25afb5db756874648c5007e16782),
            uint256(0x1de45dee073b2b1073758c3403bc8754c3e504928e78f3021e4ef700de9ea6be),
            uint256(0x16b91368250c89838ed48d4201b095c5fbaa770b429ff62d21801c1641f54c8d),
            uint256(0x1d1c50c3a040dab83b7c4c400ee303173bd1bcfcddad0966fee814d3fe980b80),
            uint256(0x0e42298d023ab2476a30bae89a1c8a80d4a44d14fa877ec7cea4f319fc7204df),
            uint256(0x205797d0f7bd2216380ac64dd996196d448cd5f1cff557853b42e1be495f37ad),
            uint256(0x00aea37039021da7fcc4f71763edfbef026941453bca796d671b20635179866d),
            uint256(0x16db862a5be1da5d185226b0ee12776b962fa9d5c722b07919a9f5e140f379ca),
            uint256(0x19e870ef007b1ed68e481490a6148cf372e0d39b6212290f451b97c2153531db),
            uint256(0x015da5218c940be95ff3aae043ce260a12e022582a0f4a5d687a4fc9ccbcd28e),
            uint256(0x2c3ca3e9b35baa7dcc08bb3c83ac54e41d4c0177922d71356505230014fabb40),
            uint256(0x2e45b87598469c5d854c7c8983f436a5a5fe6d168182be1e4cb880eb13f439a6),
            uint256(0x294bf0bbc33101d07fe8bf71e38f5127de9ce8101a249e76f406f23cf156fd37),
            uint256(0x207b4e8ba52ac072e64e41cea6b69cdd1a312a1134f2d579306c55134acc098e),
            uint256(0x190624eb6559a03372789314c1caadf319809d4b37691e744600c44e28bacba6),
            uint256(0x2e02dc7033dd55fa91f6bf1ca4a101cf5ae78f0ab1424bd934f85c38b787c171),
            uint256(0x0f05f7d7251b5319a6bc7e1475340504defd4fcc57ec76c9a093ded4a7d59618),
            uint256(0x1ba55ec0406c2e38d67b7811a45098cee5fb46a0e5c4524a974c4cec80ea1e17),
            uint256(0x212cb82d77a7876e00a767553206da2f309ef466fffc7b200bb65ee7b8a7aeaf),
            uint256(0x21dc18cf953c649235501d86806cb509e74e8f6d6a001347f5cb527491313ec3),
            uint256(0x21ab387c53fa47de14ad9b15bee23807e208a4adc02f87d3c4e68bf320c2f4a1),
            uint256(0x2e10e71c283ab704301c84ff421e003dc602e53557746b98805b86de00b3b995),
            uint256(0x1b8149a3e659d1d5a71ea4b3655e5970d3c80370413255f4c5ef54e615b51b03)
        ];
    
        Pip.PubSignals memory s;
        s.recipient = payable(BOB);
        s.gas = gas;
        s.fee = _relayerFee;
        s.root = 0x2ebe2fa9b5deb26e596192200cd7ef3af29199905072e2137910e42501ebb003;
        s.nullifierHash = 0x02a48016be947d22695d63fbcb2f16964e4900062b6cc74351553b820a5bd1d0;

        // Proof is invalid if any bit of above data is incorrect

        // Withdraw
        vm.startPrank(RELAYER);

        // Cannot send wrong value amounts
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.withdraw{ value: gas+1}(p, s); 
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.withdraw{ value: gas-1}(p, s); 
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.withdraw{ value: 0}(p, s); 

        vm.expectEmit(true, true, true, true); // (to, nullifierHash, tree index, root)
        emit Pip.Withdraw(s.recipient, s.nullifierHash, 0, 0x2ebe2fa9b5deb26e596192200cd7ef3af29199905072e2137910e42501ebb003);
        pip.withdraw{ value: gas}(p, s); 

        // Cannot withdraw twice with the same proof. (nullifierHash is used)
        vm.expectRevert(abi.encodeWithSelector(Pip.ProofInvalidOrUsed.selector));
        pip.withdraw{ value: gas}(p, s); 

        vm.stopPrank();

        // Cannot withdraw fees if you aren't the owner.
        vm.expectRevert();
        pip.withdrawFees();
        vm.stopPrank();

        assertEq(address(pip).balance, 0, "holds no native tokens, ERC20 deposit");
        assertEq(address(ALICE).balance, INITIAL_ETH, "Depositor gave no native tokens");
        assertEq(address(RELAYER).balance, INITIAL_ETH - gas, "Relayer gave gas");
        assertEq(token.balanceOf(RELAYER), relayerFee, "Relayer got fee in tokens");
        assertEq(token.balanceOf(BOB), INITIAL_TOKENS + withdrawAmount, "Recipient got withdraw");
        assertEq(address(BOB).balance, INITIAL_ETH + gas, "Recipient got gas");

        // withdraw fees
        vm.startPrank(OWNER);
        assertEq(token.balanceOf(OWNER), 0, "Before withdrawing fee");
        pip.withdrawFees();
        assertEq(pip.ownerFees(), 0, "All fees withdrawn");
        assertEq(token.balanceOf(OWNER), ownerFee, "After withdrawing fee");
        assertEq(address(pip).balance, 0, "(deposit --> withdraw) full cycle");
        assertEq(token.balanceOf(address(pip)), 0, "(deposit --> withdraw) full cycle");

        vm.stopPrank();
    }


    // ERC20 withdraws gas = ~368,000 no relayer
    function testUserWithdrawERC20() public {
        uint256 _denomination = 100e18;
        uint256 _relayerFee = 0;
        uint256 gas = 0; 

        uint256 ownerFee = _denomination * OWNER_FEE / 10000;
        uint256 relayerFee = _denomination * _relayerFee / 10000;
        uint256 totalFee = ownerFee + relayerFee;
        uint256 withdrawAmount = _denomination - totalFee;
        deployPool(false, _denomination, false);

        uint256 nullifier0 = createNullifier(bytes32(uint256(0)));
        //bytes32 nullifierHash0 = createNullifierHash(nullifier0, pip.leafIndex()); // leafIndex = 0
        bytes32 c0 = createCommitment(nullifier0);

        // DEPOSIT
        vm.startPrank(ALICE);
        token.approve(address(pip), _denomination); // Can also just approve denomination only.
        pip.deposit(c0);
        assertEq(address(pip).balance, 0, "pip got no native tokens");
        assertEq(token.balanceOf(address(pip)), _denomination, "pip got deposit");
        vm.stopPrank();

        // can be lazy and use same proof values as the User ETH withdraw
        // Because we used all the same data for the witness generation
        // In reality, obviously all `nullifierHash` will be unique for each deposit/proof.
        uint256[24] memory p = [
            uint256(0x2cda3043edcf91844be6e8be65e29a6a84b809e310e2c441336b0e9c255d1045),
            uint256(0x275931589ec68ad4da3da0a93d63ad6bc1d8fc71b944f6c0bc656084b247daaa),
            uint256(0x03473bc0b46331b1dcfef263784209f65391471361c41611ef644a4b63d9d285),
            uint256(0x11cfcaf117335fa8906eadf0c60b263e3db9e57166037a2c422ddbdb0ca5e7ef),
            uint256(0x141ccd687c66a4e9a95fda3cf3ab079a727488b4288bd3d8513d79f2f0bf652c),
            uint256(0x300e5d69e1a26809fe9b78a1402603581773b148ba1dd3f63707c99309e54caf),
            uint256(0x13385c31b8a1b9e9d5bf46a00c5a7fe4201d1cb22e0bb9b7444087c55aad024f),
            uint256(0x2d2a260eefa40b12a2f30541a4ddfcf32b27686821946acb9d358c9fb7c9e902),
            uint256(0x19a4f73dfedc0836957d2d4d22815faaf2d95f4e0bdd4abe4f05fbd296524c26),
            uint256(0x27ed193598e778d2f909916c479242bd0eb291b5b7fb8e2724f1605f78b0448b),
            uint256(0x17c7fe99fbb0134cff24bde06cc08efd2a5db7a83930e5dfc3c6e3fb30907027),
            uint256(0x1470772928d11a4e05c23fecccf641b2427836162ab482197bd4ea48a4854d12),
            uint256(0x046b0c07d4d2e445b3eddfbfa12d4243d4d6bf692bf05fa8bbe1da4d7d306fec),
            uint256(0x1c177da23ff2696a340a6ac1f8ad42de7afb152faaa087f58134d5d130d9b88f),
            uint256(0x05040cfe171a0e0729f5c8015a7836eb5316384c02235963f7d14bb61bbde20d),
            uint256(0x1c90469b36056d358743665510d1faa2765548215f2645218676a24e05b10ce4),
            uint256(0x0619223e599ef2d4e2ef777e7a8a7b6facdea7a6b1b3b54fb28a5e7d04ed70b4),
            uint256(0x2a38fa2f09afc6e1195339157bb50c0e8e419800e91e90b8eeefb48315e48080),
            uint256(0x05a30b41e17c948fb925811c69babb1f41ddb939d9bf31c1c560da20b84001db),
            uint256(0x0d37e0ea090481ed9a95166337be766a6999260fe9ee7b64bacbd77ed0e9571c),
            uint256(0x291de38db51d60d2de9e1afd1d71f857b704d52e437f56d5b432b3c90d79c7b4),
            uint256(0x1feb7cf3676c3090de882a5b84b742f453aefd49a63f0293a0930578cda13aad),
            uint256(0x0f80402da3aec3732578a67b9507b714c5a520693d343006ee5cd51adc7683e8),
            uint256(0x25564497078437060e77cfc16092dfce1d0a27f019eac92f1a2911f54dfda0b9)
        ];
    
        Pip.PubSignals memory s;
        s.recipient = payable(BOB);
        s.gas = gas;
        s.fee = _relayerFee;
        s.root = 0x2ebe2fa9b5deb26e596192200cd7ef3af29199905072e2137910e42501ebb003;
        s.nullifierHash = 0x02a48016be947d22695d63fbcb2f16964e4900062b6cc74351553b820a5bd1d0;

        // Proof is invalid if any bit of above data is incorrect

        // Withdraw (user, no relayer)
        vm.startPrank(BOB);

        // Cannot send gas
        vm.expectRevert(abi.encodeWithSelector(Pip.IncorrectPayment.selector));
        pip.withdraw{ value: 1}(p, s); 

        vm.expectEmit(true, true, true, true); // (to, nullifierHash, tree index, root)
        emit Pip.Withdraw(s.recipient, s.nullifierHash, 0, 0x2ebe2fa9b5deb26e596192200cd7ef3af29199905072e2137910e42501ebb003);
        pip.withdraw(p, s); 

        // Cannot withdraw twice with the same proof. (nullifierHash is used)
        vm.expectRevert(abi.encodeWithSelector(Pip.ProofInvalidOrUsed.selector));
        pip.withdraw{ value: gas}(p, s); 

        vm.stopPrank();

        // Cannot withdraw fees if you aren't the owner.
        vm.expectRevert();
        pip.withdrawFees();
        vm.stopPrank();

        assertEq(address(pip).balance, 0, "holds no native tokens, ERC20 deposit");
        assertEq(address(ALICE).balance, INITIAL_ETH, "Depositor gave no native tokens");
        assertEq(token.balanceOf(BOB), INITIAL_TOKENS + withdrawAmount, "Recipient got withdraw");

        // withdraw fees
        vm.startPrank(OWNER);
        assertEq(token.balanceOf(OWNER), 0, "Before withdrawing fee");
        pip.withdrawFees();
        assertEq(pip.ownerFees(), 0, "All fees withdrawn");
        assertEq(token.balanceOf(OWNER), ownerFee, "After withdrawing fee");
        assertEq(address(pip).balance, 0, "(deposit --> withdraw) full cycle");
        assertEq(token.balanceOf(address(pip)), 0, "(deposit --> withdraw) full cycle");

        vm.stopPrank();
    }

    // WARNING: This test does over 8,000 deposits & withdraws and takes ~30 seconds to run. Comment out or --mt to avoid.
    // Creates over 2 full trees, and withdraws from all trees
    // ETH pool is easy so it will be ETH, no relayer just user withdrawing
    function testMultipleTrees() public {

        uint256 _denomination = 1e18;
        uint256 _numDeposits = 8261; // 4096*2+69 = 2 full trees and 69 deposits in 3rd tree. (tree index 2)
        uint256 _aliceDeposits = 6969;
        uint256 _bobDeposits = _numDeposits - _aliceDeposits; // 1292

        //uint256 _relayerFee = 0; // stack too deep
        //uint256 gas = 0; // stack too deep
        uint256 ownerFee = _denomination * OWNER_FEE / 10000;
        //uint256 totalFee = ownerFee + relayerFee; // stack too deep
        uint256 withdrawAmount = _denomination - ownerFee;

        deployPool(true, _denomination, true); // using mock verifier.

        for (uint256 i = 0; i < _numDeposits; i++) {

            vm.recordLogs();

            address depositor = (i < _aliceDeposits) ? ALICE : BOB;
            vm.startPrank(depositor);
            pip.deposit{value: _denomination}(createCommitment(createNullifier(bytes32(uint256(i)))));
            vm.stopPrank();

            // Only record roots at our sample indices
            // Random indices to grab the root from. (could also just use first root from each tree, doesn't matter).
            // Still need atleast 1 valid root per tree for the mock verifier to work. (withdraw requires it).
            // In reality, root should/would always need to be the latest, 
            // but all we need to do is pass the `roots` mapping check for existence.
            if (i == 1337 || i == 6969 || i == 8222) {
                Vm.Log[] memory logs = vm.getRecordedLogs();
                bytes32 depositEventSignature = keccak256("Deposit(bytes32,uint256,uint256,bytes32)");
                for (uint256 j = 0; j < logs.length; j++) {
                    if (logs[j].topics[0] == depositEventSignature) {
                        bytes32 root;
                        bytes memory logData = logs[j].data;
                        assembly {
                            root := mload(add(logData, 32)) // 4th event --> first topic as data
                        }
                        console.log("Root:", uint256(root));
                        break;
                    }
                }
            }
        }

        /*
            Tree index 0: Root: 12356737170941183258296613429694156366110675045820503095645713703970176994857
            Tree index 1: Root: 7726312287440319105692562439890609878816829006061545597520991803808781703966
            Tree index 2: Root: 21413884083576682564261029916113514985263621296193920576763426123045216259335
        */

        assertEq(address(pip).balance, _numDeposits * _denomination, "got all deposits");
        assertEq(address(ALICE).balance, INITIAL_ETH - (_aliceDeposits * _denomination), "depositor");
        assertEq(address(BOB).balance, INITIAL_ETH - (_bobDeposits * _denomination), "depositor");
        assertEq(pip.treeIndex(), _numDeposits / (2**HEIGHT), "3rd tree (index 2), 8261/4096");
        // Last deposit is deposit #69 and leaf index 68. After this final deposit, leafIndex ticks over to 69, prepping for next deposit.
        assertEq(pip.leafIndex(), 69, "(8261/4096 = 2 and 69/4096.");

        uint256 bobInitial = INITIAL_ETH - (_bobDeposits * _denomination); // deficit of 1292
        // dummy proof values
        uint256[24] memory p0 = [uint256(0),1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23]; 

        {
            // tree index 0 root 
            Pip.PubSignals memory s0;
            s0.recipient = payable(BOB);
            s0.gas = 0;
            s0.fee = 0;
            s0.root = bytes32(uint256(12356737170941183258296613429694156366110675045820503095645713703970176994857));
            s0.nullifierHash = bytes32(uint256(694206969));

            // tree index 1 root 
            Pip.PubSignals memory s1;
            s1.recipient = payable(BOB);
            s1.gas = 0;
            s1.fee = 0;
            s1.root = bytes32(uint256(7726312287440319105692562439890609878816829006061545597520991803808781703966));
            s1.nullifierHash = bytes32(uint256(13371337));

            // tree index 2 root 
            Pip.PubSignals memory s2;
            s2.recipient = payable(BOB);
            s2.gas = 0;
            s2.fee = 0;
            s2.root = bytes32(uint256(21413884083576682564261029916113514985263621296193920576763426123045216259335));
            s2.nullifierHash = bytes32(uint256(777777777));
            
            vm.startPrank(BOB);

            pip.withdraw(p0,s0);
            assertEq(address(pip).balance, (_numDeposits * _denomination) - withdrawAmount, "ye");

            pip.withdraw(p0,s1);
            assertEq(address(pip).balance, (_numDeposits * _denomination) - (2 * withdrawAmount), "ye");

            pip.withdraw(p0,s2);
            assertEq(address(pip).balance, (_numDeposits * _denomination) - (3 * withdrawAmount), "ye");

            assertEq(BOB.balance, bobInitial + (3 * withdrawAmount));
            vm.stopPrank();
        }

        // Withdraw 4095 more times from tree index 0
        {
            Pip.PubSignals memory s;
            s.recipient = payable(BOB);
            s.gas = 0;
            s.fee = 0;
            s.root = bytes32(uint256(12356737170941183258296613429694156366110675045820503095645713703970176994857));
            
            vm.startPrank(BOB);
            for (uint256 i = 0; i < 4095; i++) {
                s.nullifierHash = bytes32(uint256(1000000) + i);
                pip.withdraw(p0, s);
            }
            vm.stopPrank();
        }

        // Withdraw remaining deposits from tree 1 (4095 more)
        {
            Pip.PubSignals memory s;
            s.recipient = payable(BOB);
            s.gas = 0;
            s.fee = 0;
            s.root = bytes32(uint256(7726312287440319105692562439890609878816829006061545597520991803808781703966));
            
            vm.startPrank(BOB);
            for (uint256 i = 0; i < 4095; i++) {
                s.nullifierHash = bytes32(uint256(2000000) + i);
                pip.withdraw(p0, s);
            }
            vm.stopPrank();
        }

        // Withdraw remaining deposits from tree 2 (68 more)
        {
            Pip.PubSignals memory s;
            s.recipient = payable(BOB);
            s.gas = 0;
            s.fee = 0;
            s.root = bytes32(uint256(21413884083576682564261029916113514985263621296193920576763426123045216259335));
            
            vm.startPrank(BOB);
            for (uint256 i = 0; i < 68; i++) {
                s.nullifierHash = bytes32(uint256(3000000) + i);
                pip.withdraw(p0, s);
            }
            vm.stopPrank();
        }

        assertEq(address(pip).balance, _numDeposits * ownerFee, "has only owner fees left");
        // owner fees already baked into the withdrawAmount
        assertEq(BOB.balance, bobInitial + (_numDeposits * withdrawAmount));

        // OWNER withdrawals fees
        vm.startPrank(OWNER);
        assertEq(pip.ownerFees(), _numDeposits * ownerFee, "fees accumulated");
        pip.withdrawFees();
        assertEq(OWNER.balance, INITIAL_ETH + (_numDeposits * ownerFee), "got fees");
        assertEq(address(pip).balance, 0, "deposit --> withdraw full cycle");
        vm.stopPrank();
    }


    function testChangeOwner() public {
        uint256 _denomination = 1e18;
        deployPool(false, _denomination, true);

        // Owner changes ownership to relayer.
        vm.startPrank(OWNER);
        pip.transferOwnership(RELAYER);

        // Owner can no longer call `withdrawFees()`
        vm.expectRevert();
        pip.withdrawFees();
        vm.stopPrank();

        // Switch to Relayer who can call `withdrawFees()`
        vm.startPrank(RELAYER);
        pip.withdrawFees();

        // Transfer ownership to Bob, and then Relayer cannot call `withdrawFees()`
        pip.transferOwnership(BOB);
        vm.expectRevert();
        pip.withdrawFees();
        vm.stopPrank();

        // Bob can call `withdrawFees()` and then renounce ownership and cannot `withdrawFees()`
        vm.startPrank(BOB);
        pip.withdrawFees();
        pip.renounceOwnership();
        vm.expectRevert();
        pip.withdrawFees();
        vm.stopPrank();
    }
}