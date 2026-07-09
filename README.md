# supply-chain-demo

Smart contracts that bring **traceability and integrity** to a supply chain flow. This is the **blockchain layer only** — a study/pitch project built to production-grade standards, with a real mainnet deployment as its end goal.

## What it does

A traditional supply chain keeps its data in off-chain systems. This project anchors the **critical events** and the **integrity proof** of each lot on-chain, so any participant can independently verify the history and detect tampering.

The unit of work is a **Batch** that flows through a lifecycle, with each transition performed by a distinct authorized actor:

```
Created ──▶ Audited ──▶ InTransit ──▶ Delivered
   (any state) ──▶ Blocked ──▶ (back to previous state)
```

| Actor        | Action                                        |
| ------------ | --------------------------------------------- |
| Manufacturer | Creates a batch (`createBatch`)               |
| Auditor      | Anchors the audit hash (`linkAudit`)          |
| Carrier      | Takes custody (`passCustody`)                 |
| Receiver     | Confirms delivery (`confirmDelivery`)         |
| Admin        | Manages roles; can block/unblock a batch      |

## Hybrid on/off-chain model

The full business artifact (documents, operational data) stays **off-chain**. Only its **hash** and the **critical event history** go **on-chain**. Integrity verification is simple:

1. Retrieve the off-chain artifact → 2. Recompute its hash → 3. Compare with the hash anchored on-chain → 4. If they match, the artifact is unchanged.

## Tech stack

Hardhat 3 · `hardhat-toolbox-viem` v5 · Solidity `^0.8.35` · OpenZeppelin Contracts v5 · viem v2 · TypeScript (strict). Roles via `AccessControl`; safety via `Pausable` and `ReentrancyGuard`.

## Project structure

```text
contracts/
  interfaces/ISupplyChainDemo.sol   # domain interface (enum, struct, events, functions)
  libraries/SupplyChainErrors.sol   # custom errors
  SupplyChainDemo.sol               # main contract (in progress)
test/                               # TypeScript/viem tests
scripts/                            # deploy & demo scripts
ignition/                           # Hardhat Ignition deployment modules
hardhat.config.ts
```

## Getting started

The toolchain (Node, Hardhat, Foundry) runs in a **dev container** — see [`AGENTS.md`](AGENTS.md) for how to detect your environment and run commands. Once inside an equipped environment:

```bash
npm run compile     # compile contracts
npm run test        # run all tests (Solidity + TypeScript)
npm run coverage    # coverage report (target ≥ 95%)
npm run lint:sol    # solhint
```

## Documentation

- **[ROADMAP.md](ROADMAP.md)** — phased implementation plan and current status.
- **[AGENTS.md](AGENTS.md)** (= `CLAUDE.md`) — conventions, security rules, domain details, and environment setup for contributors and AI agents.

## Scope

In scope: smart contracts, tests, deployment scripts, and technical docs. **Out of scope:** frontend, backend APIs, databases, and real signature/CA integration — these live in separate repositories.
