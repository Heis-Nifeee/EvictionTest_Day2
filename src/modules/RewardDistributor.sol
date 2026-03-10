// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IRewardDistributor.sol";
import "../lib/AresErrors.sol";
import "../lib/MerkleProof.sol";
import "../lib/ReentrancyGuard.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract RewardDistributor is IRewardDistributor, ReentrancyGuard {
    address public immutable token;
    address public treasury;
    bytes32 public merkleRoot;

    mapping(uint256 => uint256) private claimedBitMap;

    event RootUpdated(bytes32 indexed newRoot);
    event Claimed(uint256 indexed index, address indexed account, uint256 amount);

    constructor(address _token) {
        if (_token == address(0)) revert AresErrors.Unauthorized();
        token = _token;
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

    function isClaimed(uint256 index) public view returns (bool) {
        uint256 wordIndex = index / 256;
        uint256 bitIndex = index % 256;
        uint256 mask = 1 << bitIndex;
        return claimedBitMap[wordIndex] & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 wordIndex = index / 256;
        uint256 bitIndex = index % 256;
        uint256 mask = 1 << bitIndex;
        claimedBitMap[wordIndex] |= mask;
    }

    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        if (isClaimed(index)) revert AresErrors.DoubleClaim();

        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        if (!MerkleProof.verify(merkleProof, merkleRoot, node))
            revert AresErrors.InvalidProof();

        _setClaimed(index);
        _safeTransfer(account, amount);
        emit Claimed(index, account, amount);
    }

    function updateRoot(bytes32 newRoot) external onlyTreasury {
        merkleRoot = newRoot;
        emit RootUpdated(newRoot);
    }

    function _safeTransfer(address to, uint256 amount) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success) revert AresErrors.CallFailed();
        if (data.length > 0 && !abi.decode(data, (bool)))
            revert AresErrors.CallFailed();
    }
}
