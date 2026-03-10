// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ITimeDelayEngine.sol";
import "../lib/AresErrors.sol";
import "../lib/ReentrancyGuard.sol";

contract TimeDelayEngine is ITimeDelayEngine, ReentrancyGuard {
    uint256 public immutable minDelay;
    address public treasury;

    mapping(bytes32 => uint256) public queuedAt;

    constructor(uint256 _minDelay) {
        if (_minDelay == 0) revert AresErrors.InvalidLength();
        minDelay = _minDelay;
    }

    function setTreasury(address _treasury) external {
        if (treasury != address(0) && msg.sender != treasury)
            revert AresErrors.Unauthorized();
        treasury = _treasury;
    }

    modifier onlyTreasury() {
        if (msg.sender != treasury) revert AresErrors.Unauthorized();
        _;
    }

    event Queued(bytes32 indexed proposalHash, uint256 queuedAt);
    event Executed(bytes32 indexed proposalHash, uint256 executedAt);

    function queue(bytes32 proposalHash) external onlyTreasury {
        if (queuedAt[proposalHash] != 0)
            revert AresErrors.ProposalAlreadyExists();
        queuedAt[proposalHash] = block.timestamp;
        emit Queued(proposalHash, block.timestamp);
    }

    function verifyReady(bytes32 proposalHash) external view returns (bool) {
        uint256 qt = queuedAt[proposalHash];
        if (qt == 0) revert AresErrors.ProposalNotCommitted();
        if (block.timestamp < qt + minDelay) return false;
        return true;
    }

    function markExecuted(bytes32 proposalHash) external onlyTreasury nonReentrant {
        uint256 qt = queuedAt[proposalHash];
        if (qt == 0) revert AresErrors.ProposalNotCommitted();
        if (block.timestamp < qt + minDelay) revert AresErrors.DelayNotMet();
        queuedAt[proposalHash] = 0; // Prevent replay
        emit Executed(proposalHash, block.timestamp);
    }

    function getMinDelay() external view returns (uint256) {
        return minDelay;
    }
}
