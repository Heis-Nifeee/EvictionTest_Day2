**Architecture Overview**
This repo models a timelocked treasury with signed proposals plus a small rewards module. It is intentionally compact so the behavior is easy to read and audit. The system splits into three pieces. `AresTreasury` validates proposals and executes call batches. `TimeDelayEngine` enforces a minimum delay before actions can run. `RewardDistributor` handles Merkle based claims for tokens.

**Module Layout**
`src/core` contains the treasury, which acts as the coordinator. `src/modules` contains the timelock and rewards distributor. `src/lib` provides typed data hashing, a reentrancy guard, Merkle proof checks, structs, and custom errors. The seperation matters because the timelock and distributor only trust the treasury, which keeps the trust surface small and obvious.

**Treasury Core**
The treasury accepts a list of calls, a nonce, and an EIP-712 signature. Each call is a tuple of `target`, `value`, and `data`. The treasury hashes the calls to produce a `callsHash` that commits to the exact batch. This hash is embedded in the typed data struct, which the proposer signs. The contract recovers the signer and verifies it matches the proposer. If the signature or nonce is wrong, it reverts.

On success, the treasury increments the proposer nonce, stores a `Proposal` record, and forwards the proposal hash to the timelock. Execution is allowed only after the timelock delay has passed, and only if the caller supplies the same calls array that produces the original `callsHash`. Execution is raw: a low level `call` for each entry, and any failure reverts the whole batch.

**Timelock Engine**
The timelock stores `queuedAt` timestamps keyed by proposal hash. It enforces a single immutable `minDelay` set in the constructor. The treasury is the only authorized caller. `queue` sets a timestamp and `markExecuted` checks the delay before clearing it. The engine does not handle cancellation or admin reconfiguration, which keeps it simple but not feature complete.

**Reward Distribution**
The reward distributor is a classic Merkle airdrop contract. A Merkle root represents the full distribution set. Each user submits a claim with an index, account, amount, and proof. A bitmap tracks whether an index has already been claimed, so the same leaf cannot be claimed twice. Only the treasury can update the root, which is a trust assumption; if the root is wrong, claims fail. That is fine for a demo but not ideal for prodcution.

**Libraries and Guards**
`EIP712.sol` handles domain separation and digest creation. `ReentrancyGuard.sol` prevents nested calls. `MerkleProof.sol` verifies a sorted Merkle tree. `AresStructs.sol` defines the proposal and call structs, and `AresErrors.sol` centralizes custom errors so reverts are clear and gas efficient.

**Data Flow and Trust Boundries**
Off chain, a proposer builds the call list and signs the typed data digest. On chain, `AresTreasury.propose` verifies the signature and queues the proposal. The timelock records the queue time. After `minDelay`, `AresTreasury.execute` runs the calls and marks the proposal executed. Optionally, the treasury updates the rewards root and users claim with proofs. Trust boundaries are narrow: the timelock and distributor only trust the treasury, and the treasury trusts the signer plus the call data hash. The system is only as safe as the treasury keys and operational process.

**Known Gaps**
There is no proposal cancellation, no guardian role, and no explicit governance layer. There is no on chain quorum. The timelock delay is fixed. The reward distributor does not support multiple token types or claim windows. These tradeoffs keep the system small and readable.

Overall, the architecture is lean and purpose built: a timelocked treasury with an example distribution module, stitched together by minimal interfaces and small libraries. It is a good base for experiments, but it is not a production ready system as is.
