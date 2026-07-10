# ROADMAP — supply-chain-demo

> Last updated: 2026-07-10 · Status: **Phase 1 next** — Phase 0 done: compiler + pragma + solhint all aligned at `0.8.35`; project compiles and lints clean. Interface and errors library are settled (naming/semantics reviewed). Main contract not yet implemented.

## Context & goal

Blockchain-only layer of a supply chain demo: smart contracts that anchor critical supply chain events (batch registration, audit hash, custody, delivery) with a hybrid model — full artifacts off-chain, integrity hash + event history on-chain. It is study/pitch-oriented but held to production-grade standards. **Final goal: real mainnet deployment.**

Conventions and domain details live in `AGENTS.md` (= `CLAUDE.md`). This file is the execution plan.

## Stack & confirmed decisions

| Decision                | Choice                                                          | Reason                                             |
| ----------------------- | -------------------------------------------------------------- | ------------------------------------------------- |
| Stack                   | Hardhat 3 · hardhat-toolbox-viem v5 · OZ v5 · viem v2 · TS strict | Modern viem toolbox; no ethers                    |
| Solidity version        | `^0.8.35` (compiler + pragma + solhint all aligned)            | Consistency; latest features                       |
| `batchId` type          | `bytes32`                                                      | Gas-efficient, production-grade                    |
| Lifecycle               | `Created → Audited → InTransit → Delivered`; `Blocked` reversible via unblock | Matches implemented interface; no recall          |
| Source of truth         | `ISupplyChainDemo.sol` + `SupplyChainErrors.sol`              | Code over legacy docs; obsolete names dropped      |
| Workflow                | Phase by phase, review between each                            | Catch issues early, no wasted rework               |

## Current state (real)

| Item                                        | Status                                              |
| ------------------------------------------- | --------------------------------------------------- |
| Tooling/config (package.json, tsconfig, solhint, prettier, .env.example) | ✅ Done                    |
| `contracts/interfaces/ISupplyChainDemo.sol` | ✅ Done — enum, struct, events, function signatures |
| `contracts/libraries/SupplyChainErrors.sol` | ✅ Done — 6 custom errors (incl. `BatchAlreadyBlocked`) |
| `hardhat.config.ts` compiler version        | ✅ `0.8.35` in both `default` and `production` profiles — compiles & lints clean |
| `contracts/SupplyChainDemo.sol`             | ⬜ Empty — main contract not implemented             |
| `contracts/SupplyChainDemo.t.sol`           | ⬜ Empty                                             |
| `test/`, `scripts/`, `ignition/modules/`    | ⬜ Empty directories                                 |
| `docs/`, `inspection/`                      | ⬜ Do not exist                                      |

## Phases

Sequential dependency. Do not start a phase before the previous one is reviewed and approved.

### Phase 0 — Align foundation ✅
- [x] `hardhat.config.ts` solidity `version` is `0.8.35` in **both** `default` and `production` profiles (already aligned).
- [x] Interface/errors naming & semantics settled: `anchorAudit`/`AuditAnchored` (was `linkAudit`/`AuditLinked`); events dropped the explicit `timestamp` param; `blockedBy`/`unblockedBy`; added `BatchAlreadyBlocked` for the re-block case.
- **Verified**: `npm run compile` (solc 0.8.35, 2 real files compile; only warnings from the empty `SupplyChainDemo.sol` stub), `npm run lint:sol` (clean).

### Phase 1 — Main contract (`contracts/SupplyChainDemo.sol`)
- [ ] `is ISupplyChainDemo, AccessControl, Pausable, ReentrancyGuard` (OpenZeppelin v5).
- [ ] Role constants: `MANUFACTURER_ROLE`, `AUDITOR_ROLE`, `CARRIER_ROLE`, `RECEIVER_ROLE` (`bytes32 public constant`).
- [ ] Implement the 6 transitions + `getBatch` / `hasBatch` per the interface.
- [ ] Store the pre-block status so `unblockBatch` restores it.
- [ ] Centralize status guards in a `private view` helper `_requireStatus(bytes32 id, BatchStatus expected)` that reverts `InvalidBatchStatus(id, current, expected)`. `blockBatch` uses the "valid from any status except `Blocked`" rule (revert `BatchAlreadyBlocked`). **No on-chain transition table** — the state graph is enforced by these guards and documented (not stored) in Phase 5.
- [ ] Enforce all security rules from `AGENTS.md`: CEI, `address(0)` validation, role checks (revert `Unauthorized`), status guards (revert `InvalidBatchStatus`), duplicate/unknown id guards, event on every transition, full NatSpec.
- **Verify**: `npm run compile`, `npm run lint:sol`.

### Phase 2 — Solidity/Forge tests (`contracts/SupplyChainDemo.t.sol`)
- [ ] Inherit `forge-std/Test.sol`.
- [ ] Happy paths: `Created → Audited → InTransit → Delivered`; and `... → Blocked → unblock` (restores prior status).
- [ ] Reverts: wrong status → `InvalidBatchStatus`; re-blocking a `Blocked` batch → `BatchAlreadyBlocked`; wrong role (`vm.prank`) → `Unauthorized`; duplicate id → `BatchAlreadyExists`; unknown id → `BatchNotFound`; `address(0)` → `InvalidAddress`.
- [ ] `vm.expectEmit` on every state transition.
- **Verify**: `npm run test:sol`.

### Phase 3 — TypeScript/viem tests
- [ ] `test/unit/SupplyChainDemo.test.ts` — `describe → context("when authorized" / "when unauthorized") → it`; `viem.assertions` (revert-with-args, emit-with-args); `loadFixture`.
- [ ] `test/integration/EndToEndFlow.test.ts` — full flow with 5 actors, 1 batch; both the Delivered and Blocked→unblock paths; assert on-chain state after each transition.
- **Verify**: `npm run test:ts`, `npm run coverage` (≥ 95% line & branch).

### Phase 4 — Deploy & demo
- [ ] Hardhat Ignition module in `ignition/modules/` — deploy contract + grant roles to configured addresses (env or hardhat accounts).
- [ ] `scripts/demo-flow.ts` — full lifecycle on `hardhatMainnet` with readable console output for a live pitch (actor, action, batch id, tx hash per step).
- **Verify**: deploy runs on `hardhatMainnet`.

### Phase 5 — Docs & inspection artifacts
- [ ] `docs/`: `domain-model.md`, `architecture.md`, `security-notes.md`, `sequence-diagram.md`.
- [ ] `inspection/`: `checklist.md`, `threat-model.md`, `decisions.md`.
- **Verify**: manual review for completeness against the final contract.

### Final — Full review + real deploy
- [ ] Complete audit of contracts, tests, scripts, artifacts.
- [ ] Deploy to Sepolia; verify all transactions.
- [ ] Deploy to mainnet.

## Conventions (enforced throughout)

`pragma solidity ^0.8.35` · custom errors only · full NatSpec · event on every state change · `address(0)` validation · Checks-Effects-Interactions · no `tx.origin` · named constants · OpenZeppelin `AccessControl`/`Pausable`/`ReentrancyGuard`. See `AGENTS.md` for the full domain model and rules.

## npm scripts reference

> **First detect your environment** (see `AGENTS.md` → "Environment — detect first, then run"): probe `command -v npm`. If it responds, run these commands directly — you're already in an equipped environment. If not, run them inside the project's container (`docker compose exec app <cmd>` from the outer repo root).

| Command                | Purpose                                    |
| ---------------------- | ------------------------------------------ |
| `npm run compile`      | Hardhat compile                            |
| `npm run test`         | All tests (Solidity + TypeScript)          |
| `npm run test:sol`     | Solidity/Forge tests only                  |
| `npm run test:ts`      | TypeScript/viem (nodejs) tests only        |
| `npm run coverage`     | Tests with coverage report                 |
| `npm run lint:sol`     | Solhint on `contracts/**/*.sol`            |
| `npm run typecheck`    | `tsc --noEmit`                             |
| `npm run format`       | Prettier write                             |
| `npm run format:check` | Prettier check                             |
| `npm run clean`        | Hardhat clean                              |
