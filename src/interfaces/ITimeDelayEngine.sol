// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITimeDelayEngine {
    function queue(bytes32 proposalHash) external;
    function verifyReady(bytes32 proposalHash) external view returns (bool);
    function markExecuted(bytes32 proposalHash) external;
    function getMinDelay() external view returns (uint256);
    function queuedAt(bytes32 proposalHash) external view returns (uint256);
}
