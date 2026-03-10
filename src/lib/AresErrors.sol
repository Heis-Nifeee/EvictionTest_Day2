// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library AresErrors {
    error InvalidSignature();
    error SignatureReplay();
    error InvalidNonce();
    error ProposalAlreadyExists();
    error ProposalNotCommitted();
    error DelayNotMet();
    error ProposalAlreadyExecuted();
    error Unauthorized();
    error CallFailed();
    error DoubleClaim();
    error InvalidProof();
    error ReentrantCall();
    error InvalidLength();
}
