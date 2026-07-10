# supply-chain-demo — Agent Guide

> This file is the source for `CLAUDE.md` (symlink → `AGENTS.md`). Keep both tools in sync by editing here.

## Project overview

Blockchain-only layer of a supply chain demo. It shows how smart contracts can anchor critical supply chain events. It is a study/pitch project, but built to **production-grade standards** — the final milestone is a real **mainnet deployment**.

- The real Hardhat project lives in **`src/`** (this directory), which is its own git repo.
- Only the blockchain layer lives here. Frontend, backend API, and off-chain DB are out of scope (separate repos).

## Stack

Hardhat 3 · `@nomicfoundation/hardhat-toolbox-viem` v5 · Solidity `^0.8.35` · OpenZeppelin Contracts v5 · viem v2 · TypeScript strict. **No ethers** — this is a viem toolbox project.

## Hybrid on/off-chain model

- **Off-chain**: full business artifacts, audit documents, user management, operational data.
- **On-chain**: critical events, state transitions, artifact hashes, custody records.
- **Principle**: the full artifact lives off-chain; its integrity proof (hash) and critical event history are anchored on-chain. Verification = re-hash the off-chain artifact and compare with the on-chain hash.

## Domain model (source of truth = the code, not legacy docs)

**Entity**: `Batch` — a supply chain lot flowing through the process.

**Actors / roles**: Admin (authorizes participants), Manufacturer (creates batches), Auditor (anchors audit hash), Carrier (takes custody), Receiver (confirms delivery).

**Status enum** (`ISupplyChainDemo.BatchStatus`):

```solidity
enum BatchStatus { Created, Audited, InTransit, Delivered, Blocked }
```

**Lifecycle**: `Created → Audited → InTransit → Delivered`. `Blocked` is **reversible** — `unblockBatch` returns the batch to its status before the block. **There is no recall concept.**

**Events** (exact names): `BatchCreated`, `AuditAnchored`, `CustodyPassed`, `DeliveryConfirmed`, `BatchBlocked`, `BatchUnblocked`. Events carry no explicit `timestamp` parameter — consumers read `block.timestamp` from the log's block. The block/unblock events name the actor as `blockedBy` / `unblockedBy`.

**Custom errors** (in `contracts/libraries/SupplyChainErrors.sol`): `BatchAlreadyExists(bytes32)`, `BatchNotFound(bytes32)`, `Unauthorized(address caller, bytes32 role)`, `InvalidBatchStatus(bytes32 batchId, BatchStatus current, BatchStatus expected)`, `BatchAlreadyBlocked(bytes32)`, `InvalidAddress(address)`.

**Functions** (in `ISupplyChainDemo.sol`): `createBatch(bytes32 batchId, address receiver)`, `anchorAudit(bytes32 batchId, bytes32 auditHash)`, `passCustody(bytes32 batchId, address carrier)`, `confirmDelivery(bytes32 batchId)`, `blockBatch(bytes32 batchId)`, `unblockBatch(bytes32 batchId)`, `getBatch(bytes32) → Batch`, `hasBatch(bytes32) → bool`.

> **Status semantics**: `blockBatch` is valid from any status except `Blocked` (re-blocking reverts `BatchAlreadyBlocked`); every other transition has a single valid source status and reverts `InvalidBatchStatus` otherwise (`unblockBatch` expects `Blocked`).

> **State-machine enforcement**: transitions are enforced **imperatively** — the current state lives in `Batch.status`, and each transition guards its precondition via a single `private view` helper `_requireStatus(bytes32 id, BatchStatus expected)`. There is **no on-chain transition table** (a stored graph would cost gas without value for a fixed 5-state lifecycle); the state graph is documented, not stored (Phase 5 `domain-model.md` / `sequence-diagram.md`).

> Do NOT reintroduce legacy names (`AuditLinked`, `linkAudit`, `CustodyTransferred`, `BatchRecalled`, `UnauthorizedActor`). They are obsolete.

## Security rules — always enforce

- Custom errors only — never string messages in `require`.
- Explicit visibility on all functions and state variables.
- Never use `tx.origin` for authorization.
- No magic numbers — use named constants (`bytes32 public constant` role ids).
- Emit an event on every state change.
- Validate every address parameter against `address(0)` (revert `InvalidAddress`).
- Follow the Checks-Effects-Interactions pattern.
- Use OpenZeppelin v5: `AccessControl` (roles), `Pausable` (emergency stop), `ReentrancyGuard`.
- Full NatSpec (`@title`, `@author`, `@notice`, `@dev`, `@param`, `@return`) on every contract, interface, and function.

## Testing standards

- Coverage target: **≥ 95%** line and branch on all contracts.
- Required categories: happy paths, access control (every unauthorized call reverts `Unauthorized`), invalid state transitions (revert `InvalidBatchStatus`), edge cases (`address(0)`, duplicate ids → `BatchAlreadyExists`, unknown id → `BatchNotFound`), and event assertions on every transition.
- Two test layers: Solidity/Forge (`contracts/*.t.sol`, `vm.expectEmit`, `vm.prank`) and TypeScript/viem (`test/`, `viem.assertions`, `loadFixture`).
- TS structure: `describe → context("when authorized" / "when unauthorized") → it`.

## Environment — detect first, then run

> **Do NOT assume where you are. Detect your environment BEFORE running any toolchain command.**
> This project's toolchain (Node/npm/Hardhat/Foundry) lives inside a container. You may be running *inside* that container already, or *outside* it on the host — the two need different handling.

**Step 1 — probe for the toolchain where you are:**

```bash
command -v npm && npm --version
```

- **If it responds** → you are already in an equipped environment (e.g. inside the dev container). Run `npm`/`hardhat`/`npx`/`forge` commands **directly**. Ignore everything about containers below — you're already there.
- **If it fails** (`npm: command not found`) → you are on the host, outside the container. Go to Step 2.

**Step 2 — only if the toolchain is missing: find and enter the project's container.**

Inspect the Docker files in the **outer repo root** (one level above `src/`): `docker-compose.yml`, `Dockerfile`, `.devcontainer/devcontainer.json`. From them, identify the service/container, then run commands inside it. For the current setup (service `app`, container `supply-app`), from the outer repo root:

```bash
docker compose up -d                       # start the container if not running
docker compose exec app bash               # shell inside → lands in /app/supply-chain-demo
# or run one-off commands:
docker compose exec app npm run compile
docker compose exec app npm run test:sol
```

VS Code / Cursor alternative: "Reopen in Container" (uses `.devcontainer/devcontainer.json`; `postCreateCommand` runs `npm ci`, `postStartCommand` runs `npx hardhat compile`).

**Layout note (important):** on the host the project is at `src/`. Inside the container that same tree is bind-mounted at **`/app/supply-chain-demo`** (the working dir) — so there is no `src/` nesting inside the container; the project root is the workspace root.

## Working in this project

When writing or modifying tests, configuring `hardhat.config.ts`, or interacting with the network from TypeScript, invoke the **`hardhat`** skill. It covers Solidity vs TypeScript testing, `forge-std` cheatcodes, the `network.create()` API, `networkHelpers`, and the compile-then-typecheck workflow. It points to the **`hardhat-toolbox-viem`** skill for toolbox specifics (clients, contract interaction, assertions).

The active plan lives in `ROADMAP.md` — work phase by phase, with review between phases.

## Out of scope for this repository

Frontend apps · backend REST APIs · database schemas · real digital-signature implementation · real certificate-authority integration · production multi-node network setup.

## Docs

- Hardhat 3 — https://hardhat.org/llms.txt
- viem — https://viem.sh/llms.txt
