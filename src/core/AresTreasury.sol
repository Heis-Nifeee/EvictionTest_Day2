// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IAresTreasury.sol";
import "../interfaces/ITimeDelayEngine.sol";
import "../lib/AresStructs.sol";
import "../lib/AresErrors.sol";
import "../lib/EIP712.sol";
import "../lib/ReentrancyGuard.sol";

contract AresTreasury is IAresTreasury, EIP712, ReentrancyGuard {
    bytes32 private constant PROPOSE_TYPEHASH =
        keccak256("Propose(address proposer,bytes32 callsHash,uint256 nonce)");
    bytes32 private constant CALL_TYPEHASH =
        keccak256("Call(address target,uint256 value,bytes data)");

    ITimeDelayEngine public timeDelayEngine;
    address public governance;

    mapping(address => uint256) public nonces;
    mapping(bytes32 => AresStructs.Proposal) public proposals;

    event Proposed(
        bytes32 indexed proposalHash,
        address indexed proposer,
        uint256 commitTime
    );
    event Executed(bytes32 indexed proposalHash, address indexed executor);

    constructor(address _timeDelayEngine) EIP712("AresTreasury", "1") {
        if (_timeDelayEngine == address(0)) revert AresErrors.Unauthorized();
        timeDelayEngine = ITimeDelayEngine(_timeDelayEngine);
        governance = msg.sender;
    }

    receive() external payable {}

    function getNonce(address account) external view returns (uint256) {
        return nonces[account];
    }

    function hashCall(
        AresStructs.Call memory c
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(CALL_TYPEHASH, c.target, c.value, keccak256(c.data))
            );
    }

    function hashCalls(
        AresStructs.Call[] calldata calls
    ) private pure returns (bytes32) {
        bytes32[] memory callHashes = new bytes32[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            callHashes[i] = hashCall(calls[i]);
        }
        return keccak256(abi.encodePacked(callHashes));
    }

    function propose(
        AresStructs.Call[] calldata calls,
        uint256 nonce,
        bytes calldata signature
    ) external returns (bytes32) {
        if (calls.length == 0) revert AresErrors.InvalidLength();
        if (nonce != nonces[msg.sender]) revert AresErrors.InvalidNonce();

        nonces[msg.sender]++;

        bytes32 callsHash = hashCalls(calls);
        bytes32 structHash = keccak256(
            abi.encode(PROPOSE_TYPEHASH, msg.sender, callsHash, nonce)
        );
        bytes32 digest = _hashTypedDataV4(structHash);

        address signer = _recoverSigner(digest, signature);
        if (signer != msg.sender) revert AresErrors.InvalidSignature();

        if (proposals[digest].state != AresStructs.ProposalState.None)
            revert AresErrors.ProposalAlreadyExists();

        timeDelayEngine.queue(digest);

        proposals[digest] = AresStructs.Proposal({
            callsHash: callsHash,
            proposer: msg.sender,
            commitTime: block.timestamp,
            state: AresStructs.ProposalState.Committed
        });

        emit Proposed(digest, msg.sender, block.timestamp);
        return digest;
    }

    function execute(
        bytes32 proposalHash,
        AresStructs.Call[] calldata calls
    ) external payable nonReentrant {
        // --- CHECKS ---
        if (calls.length == 0) revert AresErrors.InvalidLength();
        AresStructs.Proposal storage proposal = proposals[proposalHash];
        if (proposal.state == AresStructs.ProposalState.None)
            revert AresErrors.ProposalNotCommitted();
        if (proposal.state == AresStructs.ProposalState.Executed)
            revert AresErrors.ProposalAlreadyExecuted();

        bytes32 callsHash = hashCalls(calls);
        if (proposal.callsHash != callsHash) revert AresErrors.InvalidProof();

        // --- EFFECTS ---
        proposal.state = AresStructs.ProposalState.Executed;

        // --- INTERACTIONS ---
        timeDelayEngine.markExecuted(proposalHash);

        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, ) = calls[i].target.call{value: calls[i].value}(
                calls[i].data
            );
            if (!success) revert AresErrors.CallFailed();
        }

        emit Executed(proposalHash, msg.sender);
    }

    // Convenience getter for frontends or tests
    function getProposal(
        bytes32 proposalHash
    ) external view returns (AresStructs.Proposal memory) {
        return proposals[proposalHash];
    }

    function _recoverSigner(
        bytes32 digest,
        bytes memory signature
    ) internal pure returns (address) {
        if (signature.length != 65) return address(0);

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        if (v < 27) v += 27;
        if (v != 27 && v != 28) return address(0);

        // Prevent signature malleability (EIP-2)
        if (
            uint256(s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) return address(0);

        return ecrecover(digest, v, r, s);
    }
}
