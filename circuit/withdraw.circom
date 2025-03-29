pragma circom 2.2.1;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template Withdraw(height) {
    signal input recipient; // public
    signal input gas; // public 
    signal input fee; // public
    signal input nullifierHash; // public
    signal input root; // public

    signal input nullifier; // private
    signal input pathElements[height]; // private 
    signal input pathIndices[height]; // private

    component commitmentHasher = Poseidon(2);
    commitmentHasher.inputs[0] <== nullifier;
    commitmentHasher.inputs[1] <== 69420;

    component tree = MerkleTreeChecker(height);
    tree.leaf <== commitmentHasher.out;
    tree.root <== root;

    for (var i = 0; i < height; i++) {
        tree.pathElements[i] <== pathElements[i];
        tree.pathIndices[i] <== pathIndices[i];
    }

    component leafIndexB2N = Bits2Num(height);

    for (var i = 0; i < height; i++) {
        leafIndexB2N.in[i] <== pathIndices[i];
    }

    component nullifierHasher = Poseidon(2);
    nullifierHasher.inputs[0] <== nullifier;
    nullifierHasher.inputs[1] <== leafIndexB2N.out;
    nullifierHasher.out === nullifierHash;

    // Add intermediary signal with unused recipient, fee, and gas public signals
    // Probably not required but only takes 6 constraints total
    // If optimizer ignores signals that are never used, this may prevent that
    signal recipientSquare;
    signal gasSquare;
    signal feeSquare;
    recipientSquare <== recipient * recipient;
    gasSquare <== gas * gas;
    feeSquare <== fee * fee;
}


template MerkleTreeChecker(height) {
    signal input leaf;
    signal input root;
    signal input pathElements[height];
    signal input pathIndices[height];

    component selector[height];
    component hasher[height];

    for (var i = 0; i < height; i++) {
        selector[i] = DualMux();
        selector[i].in[0] <== i == 0 ? leaf : hasher[i - 1].out;
        selector[i].in[1] <== pathElements[i];
        selector[i].s <== pathIndices[i];

        hasher[i] = Poseidon(2);
        hasher[i].inputs[0] <== selector[i].out[0];
        hasher[i].inputs[1] <== selector[i].out[1];
    }

    root === hasher[height - 1].out;
}


// If s == 0 returns [in[0], in[1]] (inputs untouched)
// If s == 1 returns [in[1], in[0]] (inputs swapped)
template DualMux() {
    signal input in[2];
    signal input s;
    signal output out[2];

    s * (1 - s) === 0;
    out[0] <== (in[1] - in[0])*s + in[0];
    out[1] <== (in[0] - in[1])*s + in[1];
}

component main {public [recipient, gas, fee, nullifierHash, root]} = Withdraw(12);