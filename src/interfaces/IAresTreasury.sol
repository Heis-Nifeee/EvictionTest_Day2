// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/AresStructs.sol";
interface IAresTreasury {
    function propose(
        AresStructs.Call[] calldata calls,
        uint256 nonce,
        bytes calldata signature
    ) external returns (bytes32 proposalHash);

    function execute(
        bytes32 proposalHash,
        AresStructs.Call[] calldata calls
    ) external payable;

    function getNonce(address account) external view returns (uint256);
}
