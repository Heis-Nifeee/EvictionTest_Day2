// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/core/AresTreasury.sol";
import "../src/modules/TimeDelayEngine.sol";
import "../src/modules/RewardDistributor.sol";
import "../src/lib/AresStructs.sol";
import "../src/lib/AresErrors.sol";
import "../src/mocks/MockERC20.sol";

contract AresTreasuryTest is Test {
    AresTreasury public treasury;
    TimeDelayEngine public timeDelay;
    RewardDistributor public rewardDistributor;
    MockERC20 public token;
    uint256 constant MIN_DELAY = 2 days;
    uint256 proposerPk = 0xA11CE;
    address proposer = vm.addr(proposerPk);

    bytes32 constant PROPOSE_TYPEHASH =
        keccak256("Propose(address proposer,bytes32 callsHash,uint256 nonce)");
    bytes32 constant CALL_TYPEHASH = keccak256("Call(address target,uint256 value,bytes data)");
    bytes32 constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    function setUp() public {
        timeDelay = new TimeDelayEngine(MIN_DELAY);
        treasury = new AresTreasury(address(timeDelay));
        timeDelay.setTreasury(address(treasury));
        token = new MockERC20();
        rewardDistributor = new RewardDistributor(address(token));
        rewardDistributor.setTreasury(address(treasury));
        vm.deal(address(treasury), 100 ether);
        token.mint(address(rewardDistributor), 1000 ether);
    }

    function _hashCall(AresStructs.Call memory c) internal pure returns (bytes32) {
        return keccak256(abi.encode(CALL_TYPEHASH, c.target, c.value, keccak256(c.data)));
    }


    function _hashCalls(AresStructs.Call[] memory calls) internal pure returns (bytes32) {
        bytes32[] memory callHashes = new bytes32[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            callHashes[i] = _hashCall(calls[i]);
        }
        return keccak256(abi.encodePacked(callHashes));
    }

    function _sign(bytes32 digest) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(proposerPk, digest);
        return abi.encodePacked(r, s, v);
    }


    function _digest(
        bytes32 callsHash,
        uint256 nonce,
        uint256 chainId
    ) internal view returns (bytes32) {
        bytes32 domainSep = keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            keccak256("AresTreasury"),
            keccak256("1"),
            chainId,
            address(treasury)
        ));
        bytes32 structHash = keccak256(
            abi.encode(
                PROPOSE_TYPEHASH,
                proposer,
                callsHash,
                nonce
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
    }


    function test_proposalLifecycle() public {
        // Create call
        AresStructs.Call[] memory calls = new AresStructs.Call[](1);
        calls[0] = AresStructs.Call({target: address(0xBEEF), value: 1 ether, data: ""});

        bytes32 callsHash = _hashCalls(calls);
        uint256 nonce = treasury.getNonce(proposer);
        bytes32 digest = _digest(callsHash, nonce, block.chainid);
        bytes memory sig = _sign(digest);

        // Propose
        vm.prank(proposer);
        bytes32 proposalHash = treasury.propose(calls, nonce, sig);

        // Execute after delay
        vm.warp(block.timestamp + MIN_DELAY + 1);
        uint256 bal = address(0xBEEF).balance;
        treasury.execute(proposalHash, calls);
        assertEq(address(0xBEEF).balance, bal + 1 ether);
    }

    function test_claimRewards() public {
        bytes32 node = keccak256(abi.encodePacked(uint256(0), proposer, uint256(100)));
        vm.prank(address(treasury));
        rewardDistributor.updateRoot(node);
        rewardDistributor.claim(0, proposer, 100, new bytes32[](0));
        assertEq(token.balanceOf(proposer), 100);
    }

    // my Exploit tests

    function test_invalidSignature() public {
        AresStructs.Call[] memory calls = new AresStructs.Call[](1);
        bytes32 callsHash = _hashCalls(calls);
        uint256 nonce = treasury.getNonce(proposer);
        bytes32 digest = _digest(callsHash, nonce, block.chainid);
        bytes memory sig = _sign(digest);
        vm.prank(address(0xBADC));
        vm.expectRevert(AresErrors.InvalidSignature.selector);
        treasury.propose(calls, nonce, sig);
    }

    function test_doubleClaim() public {
        bytes32 node = keccak256(abi.encodePacked(uint256(0), proposer, uint256(100)));
        vm.prank(address(treasury));
        rewardDistributor.updateRoot(node);
        rewardDistributor.claim(0, proposer, 100, new bytes32[](0));
        vm.expectRevert(AresErrors.DoubleClaim.selector);
        rewardDistributor.claim(0, proposer, 100, new bytes32[](0));
    }

    function test_prematureExecution() public {
        AresStructs.Call[] memory calls = new AresStructs.Call[](1);
        calls[0] = AresStructs.Call({target: address(0xBEEF), value: 1 ether, data: ""});

        bytes32 callsHash = _hashCalls(calls);
        uint256 nonce = treasury.getNonce(proposer);
        bytes32 digest = _digest(callsHash, nonce, block.chainid);
        bytes memory sig = _sign(digest);
        vm.prank(proposer);
        bytes32 proposalHash = treasury.propose(calls, nonce, sig);
        vm.warp(block.timestamp + MIN_DELAY - 1);
        vm.expectRevert(AresErrors.DelayNotMet.selector);
        treasury.execute(proposalHash, calls);
    }

    function test_proposalReplay() public {
        AresStructs.Call[] memory calls = new AresStructs.Call[](1);
        calls[0] = AresStructs.Call({target: address(0xBEEF), value: 1 ether, data: ""});

        bytes32 callsHash = _hashCalls(calls);
        uint256 nonce = treasury.getNonce(proposer);
        bytes32 digest = _digest(callsHash, nonce, block.chainid);
        bytes memory sig = _sign(digest);
        vm.prank(proposer);
        bytes32 proposalHash = treasury.propose(calls, nonce, sig);
        vm.warp(block.timestamp + MIN_DELAY + 1);
        treasury.execute(proposalHash, calls);
        vm.expectRevert(AresErrors.ProposalAlreadyExecuted.selector);
        treasury.execute(proposalHash, calls);
    }

    function test_unauthorizedTimelock() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(AresErrors.Unauthorized.selector);
        timeDelay.queue(keccak256("HASH"));
    }

    function test_crossChainReplay() public {
        AresStructs.Call[] memory calls = new AresStructs.Call[](1);
        calls[0] = AresStructs.Call({target: address(0xBEEF), value: 1 ether, data: ""});

        bytes32 callsHash = _hashCalls(calls);
        uint256 nonce = treasury.getNonce(proposer);
        bytes32 digest = _digest(callsHash, nonce, block.chainid);
        bytes memory sig = _sign(digest);
        vm.chainId(999);
        vm.prank(proposer);
        vm.expectRevert(AresErrors.InvalidSignature.selector);
        treasury.propose(calls, nonce, sig);
    }
}

