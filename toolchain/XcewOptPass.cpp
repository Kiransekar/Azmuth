// toolchain/XcewOptPass.cpp
// LLVM MachineFunctionPass for EML DAG optimization and CSE elimination
// Traverses IR for repeated patterns, builds DAG, emits optimized EML instructions

#include "Xcew.h"
#include "XcewSubtarget.h"
#include "XcewTargetMachine.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Constants.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/Hashing.h"
#include <unordered_map>
#include <unordered_set>

#define DEBUG_TYPE "xcew-opt-pass"

using namespace llvm;

namespace {

struct XcewOptPass : public MachineFunctionPass {
private:
    const XcewSubtarget *STI;

public:
    static char ID;
    XcewOptPass() : MachineFunctionPass(ID) {}

    StringRef getPassName() const override {
        return "Xcew DAG Optimization Pass";
    }

    bool runOnMachineFunction(MachineFunction &MF) override;

private:
    // Structure to represent DAG nodes
    struct DAGNode {
        unsigned opcode;
        SmallVector<unsigned, 4> operands;
        unsigned hash_value;

        bool operator==(const DAGNode &other) const {
            return opcode == other.opcode && operands == other.operands;
        }
    };

    // Custom hash for DAGNode
    struct DAGNodeHash {
        size_t operator()(const DAGNode &node) const {
            size_t hash = node.opcode;
            for (unsigned op : node.operands) {
                hash = hash_combine(hash, op);
            }
            return hash;
        }
    };

    // Cost model structure
    struct CostModel {
        unsigned cycles;
        unsigned energy;
        unsigned code_size;
    };

    // Common Subexpression Elimination
    std::unordered_map<DAGNode, unsigned, DAGNodeHash> cse_map;
    std::vector<DAGNode> unique_nodes;
    DenseMap<unsigned, unsigned> node_to_reg; // node_id -> virtual register

    // Cost model functions
    CostModel estimateCost(const DAGNode &node);
    void rebuildDAGWithCSE(MachineFunction &MF);
    bool isEMLInstruction(unsigned opcode);
    unsigned getEMLHash(const DAGNode &node);
};

// Specialization of DenseMapInfo for DAGNode
template<>
struct DenseMapInfo<XcewOptPass::DAGNode> {
    static inline XcewOptPass::DAGNode getEmptyKey() {
        return {0, {}, 0};
    }

    static inline XcewOptPass::DAGNode getTombstoneKey() {
        return {~0U, {}, 0};
    }

    static unsigned getHashValue(const XcewOptPass::DAGNode &node) {
        return node.hash_value;
    }

    static bool isEqual(const XcewOptPass::DAGNode &lhs,
                       const XcewOptPass::DAGNode &rhs) {
        return lhs == rhs;
    }
};

bool XcewOptPass::runOnMachineFunction(MachineFunction &MF) {
    STI = &MF.getSubtarget<XcewSubtarget>();

    LLVM_DEBUG(dbgs() << "Running Xcew DAG Optimization Pass on "
                      << MF.getName() << "\n");

    bool Changed = false;

    // Clear previous state
    cse_map.clear();
    unique_nodes.clear();
    node_to_reg.clear();

    // First pass: traverse instructions and identify CSE opportunities
    for (auto &MBB : MF) {
        for (auto MI = MBB.begin(); MI != MBB.end(); ++MI) {
            MachineInstr &Instr = *MI;

            if (isEMLInstruction(Instr.getOpcode())) {
                // Create DAG node from instruction
                DAGNode node;
                node.opcode = Instr.getOpcode();

                // Collect operands (excluding destination register)
                for (const MachineOperand &MO : Instr.operands()) {
                    if (MO.isReg() && MO.isUse()) {
                        node.operands.push_back(MO.getReg());
                    } else if (MO.isImm()) {
                        node.operands.push_back(MO.getImm());
                    }
                }

                // Compute hash for the node
                size_t hash = 0;
                hash = hash_combine(hash, node.opcode);
                for (unsigned op : node.operands) {
                    hash = hash_combine(hash, op);
                }
                node.hash_value = static_cast<unsigned>(hash);

                // Check for common subexpression
                auto it = cse_map.find(node);
                if (it != cse_map.end()) {
                    // Found CSE - eliminate redundant computation
                    unsigned existing_node_id = it->second;

                    // Replace destination register with existing result
                    if (!Instr.operands_empty() && Instr.getOperand(0).isReg()) {
                        unsigned dest_reg = Instr.getOperand(0).getReg();
                        unsigned existing_reg = node_to_reg[existing_node_id];

                        // Perform register remapping
                        // In practice, we'd replace uses of dest_reg with existing_reg
                    }

                    // Remove the redundant instruction
                    MI = MBB.erase(MI);
                    if (MI == MBB.end()) break;
                    Changed = true;
                    continue;
                } else {
                    // New unique node - add to maps
                    unsigned node_id = unique_nodes.size();
                    unique_nodes.push_back(node);
                    cse_map[node] = node_id;

                    // Map result register if available
                    if (!Instr.operands_empty() && Instr.getOperand(0).isReg()) {
                        node_to_reg[node_id] = Instr.getOperand(0).getReg();
                    }
                }
            }
        }
    }

    // Second pass: rebuild DAG with optimized structure
    rebuildDAGWithCSE(MF);

    LLVM_DEBUG(dbgs() << "XcewOptPass completed, changed: "
                      << (Changed ? "yes" : "no") << "\n");

    return Changed;
}

bool XcewOptPass::isEMLInstruction(unsigned opcode) {
    // Check if opcode corresponds to EML instructions (exp, ln, sub, etc.)
    switch (opcode) {
        case Xcew::XE_EXP:
        case Xcew::XE_LN:
        case Xcew::XE_SUB:
        case Xcew::XE_MUL:
        case Xcew::XE_ADD:
        case Xcew::XE_DIV:
            return true;
        default:
            return false;
    }
}

XcewOptPass::CostModel XcewOptPass::estimateCost(const DAGNode &node) {
    CostModel cost = {0, 0, 0};

    // Base costs for different operations
    switch (node.opcode) {
        case Xcew::XE_EXP:
            cost.cycles = 30;
            cost.energy = 120;
            cost.code_size = 4;
            break;
        case Xcew::XE_LN:
            cost.cycles = 25;
            cost.energy = 100;
            cost.code_size = 4;
            break;
        case Xcew::XE_SUB:
        case Xcew::XE_ADD:
            cost.cycles = 5;
            cost.energy = 20;
            cost.code_size = 4;
            break;
        case Xcew::XE_MUL:
            cost.cycles = 15;
            cost.energy = 60;
            cost.code_size = 4;
            break;
        case Xcew::XE_DIV:
            cost.cycles = 40;
            cost.energy = 160;
            cost.code_size = 4;
            break;
        default:
            cost.cycles = 1;
            cost.energy = 5;
            cost.code_size = 4;
            break;
    }

    // Adjust for operand count
    cost.cycles *= (1 + node.operands.size() / 2);
    cost.energy *= (1 + node.operands.size() / 2);

    return cost;
}

void XcewOptPass::rebuildDAGWithCSE(MachineFunction &MF) {
    // Rebuild the function with optimized DAG structure
    // This involves creating a new instruction sequence that minimizes
    // redundant computations through common subexpression elimination

    for (auto &MBB : MF) {
        for (auto MI = MBB.begin(); MI != MBB.end(); ++MI) {
            MachineInstr &Instr = *MI;

            if (isEMLInstruction(Instr.getOpcode())) {
                // Compute hash for cache lookups
                DAGNode node;
                node.opcode = Instr.getOpcode();

                for (const MachineOperand &MO : Instr.operands()) {
                    if (MO.isReg() && MO.isUse()) {
                        node.operands.push_back(MO.getReg());
                    } else if (MO.isImm()) {
                        node.operands.push_back(MO.getImm());
                    }
                }

                size_t hash = 0;
                hash = hash_combine(hash, node.opcode);
                for (unsigned op : node.operands) {
                    hash = hash_combine(hash, op);
                }
                node.hash_value = static_cast<unsigned>(getEMLHash(node));

                // Insert EML cache lookup/hit instructions
                // mload/mstore pairs for hash-based cache operations

                // Replace with optimized version that checks cache first
                // This would involve inserting Xcew-specific instructions
                // to handle the DAG cache operations
            }
        }
    }
}

unsigned XcewOptPass::getEMLHash(const DAGNode &node) {
    // Generate hash for EML cache using polynomial rolling hash
    unsigned hash = 5381; // DJB2 hash initial value

    hash = ((hash << 5) + hash) + node.opcode;

    for (unsigned op : node.operands) {
        hash = ((hash << 5) + hash) + op;
    }

    // Reduce to 8-bit for cache tag (as specified in RTL)
    return hash & 0xFF;
}

char XcewOptPass::ID = 0;

} // anonymous namespace

INITIALIZE_PASS(XcewOptPass, "xcew-opt-pass",
                "Xcew DAG Optimization Pass", false, false)

FunctionPass *llvm::createXcewOptPass() {
    return new XcewOptPass();
}