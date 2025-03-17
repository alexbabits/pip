const { buildPoseidon } = require('circomlibjs');
const ZERO_VALUE = BigInt("11122724670666931127833274645309940916396779779585410472511079044548860378081");

// The values generated through this `circomlibjs` poseidon match the values generated via `PoseidonT3` on-chain.
async function buildTree(commitments, height) {

    const poseidon = await buildPoseidon();

    // tree[y][x] where y = height, x = index
    const tree = Array(height + 1).fill().map(() => []);
    
    // Fill non-zero commitment leafs at height 0
    for (let i = 0; i < commitments.length; i++) {
        tree[0][i] = commitments[i];
    }
    
    // Fill 'empty' leaf nodes at height 0 with zero value
    for (let i = commitments.length; i < 2**height; i++) {
        tree[0][i] = ZERO_VALUE;
    }
    
    // Calculate tree node values
    for (let y = 1; y <= height; y++) {

        const nodes = 2**(height - y)

        for (let x = 0; x < nodes; x++) {
            const leftChild = tree[y-1][2*x];
            const rightChild = tree[y-1][2*x+1];
            tree[y][x] = poseidon([leftChild, rightChild]);
        }
    }
    console.log(`Root:`, poseidon.F.toString(tree[height][0], 10)); // 10 for decimal, 16 for hexadecimal
    return { tree, poseidon };
}


function getPathElements(tree, leafIndex, height) {
    const pathElements = [];

    let x = leafIndex;
    
    for (let y = 0; y < height; y++) {
        const siblingX = x % 2 === 0 ? x + 1 : x - 1;
        pathElements.push(tree[y][siblingX]);
        x = Math.floor(x / 2);
    }
    
    return pathElements;
}

// Run: node build-tree.js
(async () => {
    const treeHeight = 4;
    const leafIndex = 0;

    // If you want to view all zero values of a tree, just pass in empty commitment array,
    // any leafIndex will suffice as an emptry tree has only one set of path elements
    const {tree, poseidon} = await buildTree([
        BigInt("4873845517341354240483781786684739248524789913426222845413696638288295894761"),
        BigInt("19893796767628644644508042129737146844370001181247521714447689156352108429278"), 
        BigInt("3970558148520727263457132309636987021913061380623131292344242352805121773637")
    ], treeHeight); 

    // First element is type BigInt because it's the zero value or the first commitment
    // Other elements are from poseidon hashing, which outputs arrays, so must adjust to properly log
    const pathElements = getPathElements(tree, leafIndex, treeHeight).map(element => 
        typeof element === "bigint" ? element.toString(10) : poseidon.F.toString(element, 10)
    );
    console.log(`Path Elements for leaf Index ${leafIndex}:`, pathElements);
})();


// EXAMPLE (TREE HEIGHT = 4):

// -----------------------------
// HASHES TO NODE LOCATION (x,y)
// -----------------------------
// HEIGHT = 0
// -----------------------------
// H[(0,0)|(1,0)] = (0,1) 
// H[(2,0)|(3,0)] = (1,1) 
// H[(4,0)|(5,0)] = (2,1) 
// H[(6,0)|(7,0)] = (3,1) 
// H[(8,0)|(9,0)] = (4,1) 
// H[(10,0)|(11,0)] = (5,1) 
// H[(12,0)|(13,0)] = (6,1) 
// H[(14,0)|(15,0)] = (7,1) 

// HEIGHT = 1
// -----------------------------
// H[(0,1)|(1,1)] = (0,2) 
// H[(2,1)|(3,1)] = (1,2) 
// H[(4,1)|(5,1)] = (2,2) 
// H[(6,1)|(7,1)] = (3,2) 

// HEIGHT = 2
// -----------------------------
// H[(0,2)|(1,2)] = (0,3) 
// H[(2,2)|(3,2)] = (1,3) 

// HEIGHT = 3 
// -----------------------------
// H[(0,3)|(1,3)] = (0,4) (ROOT)



// -----------------------------
// PATH ELEMENT LOCATIONS
// -----------------------------

// Leaf Index | Leaf Location (x,y) | Path Indices | Path Elements (x,y)

// Path Indices: Left = 1, Right = 0.
// Leaf Index is the decimal value that the path indices binary represents.

// 0  | (0,0)  | [0,0,0,0] | [(1,0),(1,1),(1,2),(1,3)]
// 1  | (1,0)  | [1,0,0,0] | [(0,0),(1,1),(1,2),(1,3)]
// 2  | (2,0)  | [0,1,0,0] | [(3,0),(0,1),(1,2),(1,3)]
// 3  | (3,0)  | [1,1,0,0] | [(2,0),(0,1),(1,2),(1,3)]

// 4  | (4,0)  | [0,0,1,0] | [(5,0),(3,1),(0,2),(1,3)]
// 5  | (5,0)  | [1,0,1,0] | [(4,0),(3,1),(0,2),(1,3)]
// 6  | (6,0)  | [0,1,1,0] | [(7,0),(2,1),(0,2),(1,3)]
// 7  | (7,0)  | [1,1,1,0] | [(6,0),(2,1),(0,2),(1,3)]

// 8  | (8,0)  | [0,0,0,1] | [(9,0),(5,1),(3,2),(0,3)]
// 9  | (9,0)  | [1,0,0,1] | [(8,0),(5,1),(3,2),(0,3)]
// 10 | (10,0) | [0,1,0,1] | [(11,0),(4,1),(3,2),(0,3)]
// 11 | (11,0) | [1,1,0,1] | [(10,0),(4,1),(3,2),(0,3)]

// 12 | (12,0) | [0,0,1,1] | [(13,0),(7,1),(2,2),(0,3)]
// 13 | (13,0) | [1,0,1,1] | [(12,0),(7,1),(2,2),(0,3)]
// 14 | (14,0) | [0,1,1,1] | [(15,0),(6,1),(2,2),(0,3)]
// 15 | (15,0) | [1,1,1,1] | [(14,0),(6,1),(2,2),(0,3)]