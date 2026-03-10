**Security Overview**
This project is a small treasury system with a timelock and a token rewards module. The contracts are intentionally minimal so the security model is easy to inspect. A proposer signs a batch of calls, the treasury validates the signature, the timelock enforces a delay, and then anyone can execute those calls. If the treasury keys are safe and the signature checks are correct, the system behaves as expected.

There are three trust zones: the `AresTreasury` contract, the `TimeDelayEngine` timelock, and the `RewardDistributor` airdrop module. The treasury is the control plane. The timelock and distributor only trust the treasury. Off chain signatures provide authorization, and the timelock gives time for human review.

**Main Threats**
The main threats are unauthorized execution, replay of old signatures, premature execution, reentrancy during external calls, and invalid Merkle claims. This repo does not include voting, role systems, or upgrades, so the treasury remains a single point of trust.

**Key Protections**
`AresTreasury.propose` verifies the EIP-712 signature and checks a per proposer nonce. The nonce is incremented on success, which blocks replay of the same signed message. The call list is hashed into a `callsHash` and stored in the proposal record. If execution is attempted with a different call list, the hash check reverts.

`TimeDelayEngine` enforces a single immutable `minDelay`. It stores a `queuedAt` timestamp and refuses to mark executed if the delay has not elapsed. Clearing the timestamp after execution prevents reusing the same proposal hash.

`RewardDistributor` uses a claim bitmap. If an index has already been claimed, it reverts. Merkle proof verification prevents fake claims. The token transfer uses a safe transfer pattern to avoid silent failures.

**Known Risks and Assumptions**
The biggest assumption is the treasury itself. If the treasury is compromised, the system is compromised. There is no guardian role, no emergency pause, and no cancelation flow. The timelock buys time, but it does not stop a malicious proposal if nobody acts off chain. The treasury executes raw low level calls, which is powerful but dangerous. A malicious target can do anything the treasury can do. The reward distributor also trusts the treasury to publish a correct Merkle root; if the root is wrong, claims fail. This is acceptable for a demo but not for prodcution.

**Signature and Replay Notes**
Signatures follow EIP-712 typed data. The chain id and verifying contract address are part of the domain separator, so cross chain replay is blocked. The nonce blocks replay on the same chain. The proposal hash is the digest itself, and it is used by both the treasury and the timelock. If you change the typed data fields, name, or version, you must update your off chain signer or the signatures will fail.

**Reentrancy and External Calls**
Both the treasury and reward distributor include a reentrancy guard. This prevents reentering those functions in the same transaction, but it does not protect the callee. The safest practice is to only include well understood calls and to review them during the timelock window.

**Testing Coverage**
Tests cover a basic lifecycle plus several bad paths: invalid signatures, premature execution, proposal replay after execution, unauthorized timelock access, double claims, and a chain id mismatch. This is not a complete audit, but it does exercise the most important checks.

**Operational Guidance**
If you use this for demos or study, treat it like a real treasury. Keep the proposer key in a safe place, never sign calls you do not understand, and inspect every proposal during the delay window.

**Summary**
This system is intentionally small and readable. The primary security wins are the signature checks, nonce replay protection, and timelock delay. The primary risks are centralization in the treasury and the raw external calls. Use it to learn and experiment, but do not use it as a production treasury without significant extra work.
