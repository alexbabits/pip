// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;  

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PoseidonT3} from "./libraries/PoseidonT3.sol";
import {IGroth16Verifier} from "./interfaces/IGroth16Verifier.sol";

contract Pip is Ownable {

    using SafeERC20 for IERC20;

    IGroth16Verifier public immutable verifier;
    IERC20 public immutable token;
    uint256 public immutable denomination;
    
    // ZERO_VALUE = keccak256("Pulse In Private") % FIELD_SIZE 
    uint256 public constant ZERO_VALUE = 11122724670666931127833274645309940916396779779585410472511079044548860378081; 
    uint256 public constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 public constant HEIGHT = 12;
    uint256 public constant OWNER_FEE = 20; // 0.20%
    uint256 public constant RELAYER_FEE = 5; // 0.05%
    uint256 public constant GAS = 1e14; // will be like 40,000e18 PLS for pulsechain, double check decimals.
    
    uint256 public leafIndex;
    uint256 public treeIndex;
    uint256 public ownerFees;

    mapping(bytes32 => bool) public roots; // root --> Exists?
    mapping(bytes32 => bool) public commitments; // Deposit Leaf --> Exists?
    mapping(uint256 => bytes32) public zeros; // Height --> Static "empty" values at each height of the tree
    mapping(uint256 => bytes32) public siblingNodes; // Height --> "Localized" Path Element value
    mapping(bytes32 => uint256) public rootTreeIndex; // root --> tree index
    mapping(bytes32 => mapping(ProofType => bool)) public nullifierHashes; // nullifierHash --> ProofType --> used?
    
    enum ProofType {
        Gas,
        Withdraw
    }

    struct ECPoints {
        uint256[2] pA;
        uint256[2][2] pB;
        uint256[2] pC;
    }

    struct PubSignals {
        address payable recipient;
        bytes32 nullifierHash;
        bytes32 root;
    }

    event Deposit(bytes32 indexed leaf, uint256 indexed _leafIndex, uint256 indexed _treeIndex, bytes32 root);
    event Withdraw(address indexed to, bytes32 indexed nullifierHash, uint256 indexed _treeIndex, bytes32 root);  
    event GasSent(address indexed recipient, address indexed relayer);
    event MerkleTreeReset(uint256 indexed newTreeIndex);

    error ZeroValue();
    error CommitmentAlreadyInTree();
    error NullifierHashAlreadyUsed();
    error InvalidRoot();
    error IncorrectProof();
    error IncorrectPayment();
    error PreimageExceedsFieldSize();
    error CallFailed();


    constructor(IGroth16Verifier _verifier, uint256 _denomination, IERC20 _token) Ownable(msg.sender) {
        if (_denomination == 0) revert ZeroValue();
        if (address(_verifier) == address(0)) revert ZeroValue();
        verifier = _verifier;
        denomination = _denomination;
        token = _token;

        bytes32 currentZero = bytes32(ZERO_VALUE);
        zeros[0] = currentZero;

        for (uint256 i = 1; i < HEIGHT; i++) {
            currentZero = poseidonHash(currentZero, currentZero);
            zeros[i] = currentZero;
        }
    }

    
    function deposit(bytes32 leaf) external payable {
        if (commitments[leaf]) revert CommitmentAlreadyInTree();
        commitments[leaf] = true;
        bytes32 root = _insertCommitment(leaf);
        _processDeposit();
        emit Deposit(leaf, leafIndex-1, treeIndex, root);
    }


    function withdraw(ECPoints calldata p, PubSignals calldata s) external {
        checkProof(p, s, ProofType.Withdraw);
        nullifierHashes[s.nullifierHash][ProofType.Withdraw] = true;
        _processWithdraw(s.recipient);
        uint256 _treeIndex = rootTreeIndex[s.root];
        emit Withdraw(s.recipient, s.nullifierHash, _treeIndex, s.root);
    }


    function sendGas(ECPoints calldata p, PubSignals calldata s) external {
        checkProof(p, s, ProofType.Gas);
        nullifierHashes[s.nullifierHash][ProofType.Gas] = true;

        (bool recipientSuccess, ) = s.recipient.call{value: GAS * 7500 / 10000}("");
        if (!recipientSuccess) revert CallFailed();

        uint256 relayerFee = denomination * RELAYER_FEE / 10000;

        // ETH 
        if (address(token) == address(0)) {
            (bool success, ) = msg.sender.call{ value: relayerFee + (GAS * 2500 / 10000) }("");
            if (!success) revert CallFailed();
        // ERC20
        } else {
            (bool success, ) = msg.sender.call{ value: GAS * 2500 / 10000}("");
            if (!success) revert CallFailed();
            token.safeTransfer(msg.sender, relayerFee);
        }

        emit GasSent(s.recipient, msg.sender);
    }


    function withdrawFees() external onlyOwner {
        uint256 _fees = ownerFees;
        ownerFees = 0;
        // ETH
        if (address(token) == address(0)) {
            (bool success, ) = msg.sender.call{ value: _fees }("");
            if (!success) revert CallFailed();
        // ERC20
        } else {
            token.safeTransfer(msg.sender, _fees);
        }
    }


    function checkProof(ECPoints calldata p, PubSignals calldata s, ProofType proofType) public view {
        if (nullifierHashes[s.nullifierHash][proofType]) revert NullifierHashAlreadyUsed();
        if (!roots[s.root]) revert InvalidRoot();
        if (!verifier.verifyProof(
            p.pA, 
            p.pB, 
            p.pC, 
            [uint256(uint160(address(s.recipient))), uint256(s.nullifierHash), uint256(s.root)]
        )) revert IncorrectProof();
    }


    function poseidonHash(bytes32 _left, bytes32 _right) public pure returns (bytes32) {
        if (uint256(_left) >= FIELD_SIZE) revert PreimageExceedsFieldSize();
        if (uint256(_right) >= FIELD_SIZE) revert PreimageExceedsFieldSize();
        return bytes32(PoseidonT3.hash([uint256(_left), uint256(_right)]));
    }


    function _processDeposit() private {
        // ETH
        if (address(token) == address(0)) {
            if (msg.value != denomination + GAS) revert IncorrectPayment();
        // ERC20
        } else {
            if (msg.value != GAS) revert IncorrectPayment();
            token.safeTransferFrom(msg.sender, address(this), denomination);
        }
    }


    function _processWithdraw(address payable _recipient) private {
        uint256 totalFee = denomination * (OWNER_FEE + RELAYER_FEE) / 10000;
        uint256 ownerFee = denomination * OWNER_FEE / 10000;
        uint256 withdrawAmount = denomination - totalFee;

        // ETH
        if (address(token) == address(0)) {
            (bool recipientSuccess, ) = _recipient.call{ value: withdrawAmount }("");
            if (!recipientSuccess) revert CallFailed();
        // ERC20
        } else {
            token.safeTransfer(_recipient, withdrawAmount);
        }
        ownerFees += ownerFee;
    }


    function _insertCommitment(bytes32 leaf) private returns (bytes32 root) {
        uint256 _leafIndex = leafIndex;

        if (_leafIndex == uint256(2)**HEIGHT) {
            _resetMerkleTree();
            _leafIndex = 0;
        }

        bytes32 currentLevelHash = leaf;
        bytes32 left;
        bytes32 right;

        for (uint256 i = 0; i < HEIGHT; i++) {
            if (_leafIndex % 2 == 0) {
                left = currentLevelHash;
                right = zeros[i]; 
                siblingNodes[i] = currentLevelHash;
            } else {
                left = siblingNodes[i];
                right = currentLevelHash;
            }
            currentLevelHash = poseidonHash(left, right);
            _leafIndex /= 2;
        }

        roots[currentLevelHash] = true;
        rootTreeIndex[currentLevelHash] = treeIndex;
        leafIndex += 1;
        return currentLevelHash;
    }


    function _resetMerkleTree() private {
        leafIndex = 0;
        treeIndex += 1;
        for (uint256 i = 0; i < HEIGHT; i++) {
            delete siblingNodes[i];
        }
        emit MerkleTreeReset(treeIndex);
    }

}