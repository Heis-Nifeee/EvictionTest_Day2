**Overview**
Ares is a small governance-and-treasury playground built with Foundry. The core idea is simple: a treasury can queue a batch of calls, wait a minimum delay, and then execute those calls if the signed proposal is valid. On top of that, a reward distributor lets the treasury update a Merkle root so users can claim tokens once, with replay protection. The code is small enough to read in an afternoon, which makes it handy for audits practice or learning how timelocks and EIP-712 signatures fit together.

The repo is laid out in a pretty straight‑forward way. Core contracts live in `src/core`, modules in `src/modules`, small libs in `src/lib`, and tests in `test`. There’s no fancy deployment scripts in here yet; it’s intentionally bare so the behaviors are easy to reason about.

**Key Contracts**
`AresTreasury` is the main entry point. It uses EIP‑712 typed data signing to prove that the proposer actually authorized a specific bundle of calls. It stores a per‑proposer nonce to stop replay, hashes the calls to lock in exactly what will be executed later, and records a proposal struct with state. Once a proposal is submitted, it is queued in the `TimeDelayEngine`.

`TimeDelayEngine` is a minimal timelock. It knows the minimum delay and a mapping of proposal hashes to their queued timestamps. Only the treasury can queue or mark executed, and it enforces the delay so early execution fails. The delay is immutable in the constructor, so this is more of a simple timelock than a fully governed one.

`RewardDistributor` is a Merkle airdrop style distributor. The treasury can update the Merkle root, then users can claim once by presenting their proof. A bitmap tracks which indexes were claimed so the same leaf can’t be claimed twice. It uses a safe transfer pattern and reentrancy guard to keep it predictable.

**How The Flow Works**
1. A proposer builds an array of calls (target, value, calldata) and hashes them.
2. The proposer signs the EIP‑712 digest that includes the calls hash and their current nonce.
3. The treasury verifies the signature, bumps the nonce, and queues the proposal in the timelock.
4. After the min delay passes, anyone can execute the proposal and the treasury will run the calls in order.

That’s it. The treasury holds ETH and can call any external contracts, so the timelock is basically the guardrail.

**What The Tests Cover**
The `AresTreasury.t.sol` file covers a happy path lifecycle and a few “don’t do that” cases. It checks invalid signatures, premature execution, proposal replay after execution, and unauthorized access to the timelock. There are also reward distributor tests that show updating a root and claiming once, plus a double claim revert. The tests are intentionally small but they hit the main threat surfaces.

**Local Setup**
You need Foundry. If you already have `forge` installed, you can run:

```bash
forge test
```

If you want to peek at coverage or trace logs, Foundry supports `-vvvv` for verbose output. This repo doesn’t do anything weird with config, so the default `foundry.toml` settings are enough.

**Contract Notes / Caveats**
- The treasury uses EIP‑712, so the chain id is part of the digest. This is a good default; it stops cross‑chain replay.
- The timelock only enforces a single delay and does not manage “cancel” or “grace period” concepts.
- There is no role system beyond “treasury can do X”. If the treasury is compromised, everything is compromised. That’s normal for a simple example but worth calling out.
- The reward distributor assumes a trustworthy root publisher. If the treasury publishes a bad root, users can’t claim, and that’s by design.

**Project Status**
This is a learning repo and not a production treasury. There’s no on‑chain governance, no upgrade path, and no formal audit. It’s meant to be read, tweaked, and maybe broken on purpose. If you are using it for study, my reccomendation is to step through the tests with verbose traces and watch how the state changes over time.

If you spot a bug or want to add features (like cancelable proposals, governance roles, or a grace period), feel free to branch off and experiment. The surface area is small, so it’s a nice place to learn without drowning in complexity.
