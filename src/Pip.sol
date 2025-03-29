// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;  

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PoseidonT3} from "./PoseidonT3.sol";
import {IPlonkVerifierPPOT} from "./IPlonkVerifierPPOT.sol";

contract Pip is Ownable {

    using SafeERC20 for IERC20;

    IPlonkVerifierPPOT public immutable verifier;
    IERC20 public immutable token;
    uint256 public immutable denomination;
    
    // ZERO_VALUE = keccak256("Pulse In Private") % FIELD_SIZE 
    uint256 public constant ZERO_VALUE = 11122724670666931127833274645309940916396779779585410472511079044548860378081; 
    uint256 public constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 public constant HEIGHT = 12;
    uint256 public constant OWNER_FEE = 20; // 0.20%
    
    uint256 public leafIndex;
    uint256 public treeIndex;
    uint256 public ownerFees;

    mapping(bytes32 => bool) public roots; // root --> Exists?
    mapping(bytes32 => bool) public commitments; // Deposit Leaf --> Exists?
    mapping(bytes32 => bool) public nullifierHashes; // nullifierHash --> used?
    mapping(uint256 => bytes32) public zeros; // Height --> Static "empty" values at each height of the tree
    mapping(uint256 => bytes32) public siblingNodes; // Height --> "Localized" Path Element value
    mapping(bytes32 => uint256) public rootTreeIndex; // root --> tree index
    
    struct PubSignals {
        address payable recipient;
        uint256 gas;
        uint256 fee;
        bytes32 nullifierHash;
        bytes32 root;
    }

    event Deposit(bytes32 indexed leaf, uint256 indexed _leafIndex, uint256 indexed _treeIndex, bytes32 root);
    event Withdraw(address indexed to, bytes32 indexed nullifierHash, uint256 indexed _treeIndex, bytes32 root);  
    event MerkleTreeReset(uint256 indexed newTreeIndex);

    error ZeroValue();
    error CommitmentAlreadyInTree();
    error NullifierHashAlreadyUsed();
    error InvalidRoot();
    error IncorrectProof();
    error IncorrectPayment();
    error PreimageExceedsFieldSize();
    error CallFailed(address user, uint256 value);


    constructor(IPlonkVerifierPPOT _verifier, uint256 _denomination, IERC20 _token) Ownable(msg.sender) {
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


    function withdraw(uint256[24] calldata p, PubSignals calldata s) external payable {
        if (msg.value != s.gas) revert IncorrectPayment();
        checkProof(p, s);
        nullifierHashes[s.nullifierHash] = true;
        _processWithdraw(s.recipient, s.gas, s.fee);
        uint256 _treeIndex = rootTreeIndex[s.root];
        emit Withdraw(s.recipient, s.nullifierHash, _treeIndex, s.root);
    }


    function withdrawFees() external onlyOwner {
        uint256 fees = ownerFees;
        ownerFees = 0;
        // ETH
        if (address(token) == address(0)) {
            (bool success, ) = msg.sender.call{ value: fees }("");
            if (!success) revert CallFailed(msg.sender, fees);
        // ERC20
        } else {
            token.safeTransfer(msg.sender, fees);
        }
    }


    function checkProof(uint256[24] calldata p, PubSignals calldata s) public view {
        if (nullifierHashes[s.nullifierHash]) revert NullifierHashAlreadyUsed();
        if (!roots[s.root]) revert InvalidRoot();
        if (!verifier.verifyProof(
            p,
            [uint256(uint160(address(s.recipient))), s.gas, s.fee, uint256(s.nullifierHash), uint256(s.root)]
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
            if (msg.value != denomination) revert IncorrectPayment();
        // ERC20
        } else {
            if (msg.value != 0) revert IncorrectPayment();
            token.safeTransferFrom(msg.sender, address(this), denomination);
        }
    }


    function _processWithdraw(address payable recipient, uint256 gas, uint256 _relayerFee) private {
        uint256 ownerFee = denomination * OWNER_FEE / 10000;
        uint256 relayerFee = denomination * _relayerFee / 10000;
        uint256 totalFee = ownerFee + relayerFee;
        uint256 withdrawAmount = denomination - totalFee;

        // ETH
        if (address(token) == address(0)) {
            (bool recipientSuccess, ) = recipient.call{ value: withdrawAmount + gas }("");
            if (!recipientSuccess) revert CallFailed(recipient, withdrawAmount + gas);

            if (relayerFee != 0) {
                (bool relayerSuccess, ) = msg.sender.call{ value: relayerFee }("");
                if (!relayerSuccess) revert CallFailed(msg.sender, relayerFee);
            }
        // ERC20
        } else {
            token.safeTransfer(recipient, withdrawAmount);
            if (gas != 0) {
                (bool success, ) = recipient.call{ value: gas }("");
                if (!success) revert CallFailed(recipient, gas);
            }

            if (relayerFee != 0) {
                token.safeTransfer(msg.sender, relayerFee);
            }
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