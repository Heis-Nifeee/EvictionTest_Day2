// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library AresStructs {
    enum ProposalState {
        None,
        Pending,
        Committed,
        Executed
    }

    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    struct Proposal {
        bytes32 callsHash;
        address proposer;
        uint256 commitTime;
        ProposalState state;
    }
}
