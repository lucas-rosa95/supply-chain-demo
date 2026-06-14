# Implementation Plan — supply-chain-demo

> Last updated: 2026-06-13
> Status: **Phase 1 next** — setup complete, no contract logic yet.

## Context

Blockchain-only layer of a supply chain demo. Final goal: real mainnet deployment.
Production-grade standards apply throughout — this is not a throwaway demo.

Stack: Hardhat 3 · hardhat-toolbox-viem · Solidity 0.8.28 · OpenZeppelin v5 · viem v2 · TypeScript strict.

---

## Confirmed Decisions

| Decision        | Choice                                                         | Reason                               |
| --------------- | -------------------------------------------------------------- | ------------------------------------ |
| BatchId type    | `bytes32`                                                      | Gas-efficient, production-grade      |
| Workflow        | Phase by phase, review between each                            | Catch issues early, no wasted rework |
| Final milestone | Full review + real network deploy                              | Project will go live                 |
| Template files  | Deleted `scripts/send-op-tx.ts`, `ignition/modules/Counter.ts` | Unrelated to domain                  |

---

## Current State

| File                              | Status                                                                          |
| --------------------------------- | ------------------------------------------------------------------------------- |
| `hardhat.config.ts`               | ✅ Done — plugins, solidity profiles (default + production/optimizer), networks |
| `package.json`                    | ✅ Done — scripts, deps, name corrected                                         |
| `tsconfig.json`                   | ✅ Done — strict mode, resolveJsonModule, ignition included                     |
| `.solhintrc.json`                 | ✅ Done — custom-errors:error, func-visibility:error                            |
| `.prettierrc`                     | ✅ Done — 100-char width, Solidity tabWidth:4                                   |
| `.env.example`                    | ✅ Done — SEPOLIA_RPC_URL, SEPOLIA_PRIVATE_KEY                                  |
| `contracts/SupplyChainDemo.sol`   | ⬜ Empty                                                                        |
| `contracts/SupplyChainDemo.t.sol` | ⬜ Empty                                                                        |
| `test/`                           | ⬜ Empty directory                                                              |
| `docs/`                           | ⬜ Does not exist                                                               |
| `inspection/`                     | ⬜ Does not exist                                                               |

---

## Phase Plan

Work phase by phase. Do not start the next phase before the previous one is reviewed and approved.

---

### Phase 1 — Solidity Foundation

Implement in this order (each file depends on the previous):

- [ ] `contracts/libraries/SupplyChainErrors.sol`
  - `BatchNotFound(bytes32 batchId)`
  - `BatchAlreadyExists(bytes32 batchId)`
  - `UnauthorizedActor(address caller, bytes32 role)`
  - `InvalidBatchStatus(bytes32 batchId, BatchStatus current, BatchStatus required)`
  - `InvalidAddress()`
  - Full NatSpec on all errors

- [ ] `contracts/interfaces/ISupplyChainDemo.sol`
  - `enum BatchStatus { Created, Audited, InTransit, Delivered, Blocked }`
  - `struct Batch` — id (`bytes32`), manufacturer, auditor, carrier, receiver, status (`BatchStatus`), auditHash (`bytes32`), createdAt, updatedAt
  - Events: `BatchCreated`, `AuditAnchored`, `CustodyTransferred`, `DeliveryConfirmed`, `BatchBlocked`, `BatchRecalled`
  - Function signatures for all 6 state-transition functions + view functions
  - Full NatSpec on all items

- [ ] `contracts/SupplyChainDemo.sol`
  - Inherits: `AccessControl`, `Pausable`, `ReentrancyGuard` (OpenZeppelin v5)
  - Role constants (`bytes32 public constant`): `MANUFACTURER_ROLE`, `AUDITOR_ROLE`, `CARRIER_ROLE`, `RECEIVER_ROLE`
  - Functions: `createBatch`, `anchorAudit`, `transferCustody`, `confirmDelivery`, `blockBatch`, `recallBatch`
  - Security: Checks-Effects-Interactions, `address(0)` validation on all address params, no `tx.origin`, named constants only
  - Full NatSpec

**Verification before proceeding:**

```bash
npm run compile    # no errors
npm run lint:sol   # no violations
```

---

### Phase 2 — Solidity Tests (Forge)

- [ ] `contracts/SupplyChainDemo.t.sol`
  - Inherits `forge-std/Test.sol`
  - Happy path: Created → Audited → InTransit → Delivered
  - Happy path: Created → Audited → InTransit → Blocked
  - Revert: each function called in wrong state → `InvalidBatchStatus`
  - Revert: each function called by wrong role → `UnauthorizedActor` (via `vm.prank`)
  - Revert: duplicate batch id → `BatchAlreadyExists`
  - Revert: `address(0)` inputs → `InvalidAddress`
  - Events: `vm.expectEmit` on every state transition

**Verification before proceeding:**

```bash
npm run test:sol   # all tests pass
```

---

### Phase 3 — TypeScript Tests (viem)

- [ ] `test/unit/SupplyChainDemo.test.ts`
  - Structure: `describe → context("when authorized") → it` / `context("when unauthorized") → it`
  - `viem.assertions.revertWithCustomErrorWithArgs`, `emitWithArgs`
  - Fixtures with `networkHelpers.loadFixture`

- [ ] `test/integration/EndToEndFlow.test.ts`
  - Full flow: Created → Audited → InTransit → Delivered (5 actors, 1 batch)
  - Full flow: Created → Audited → InTransit → Blocked
  - Verify on-chain state after each transition

**Verification before proceeding:**

```bash
npm run test:ts
npm run coverage   # ≥ 95% line and branch
```

---

### Phase 4 — Operational Scripts

- [ ] `scripts/deploy.ts`
  - Deploy via `network.create()`
  - Grant roles to configured addresses (from env or hardhat accounts)
  - Log deployed contract address
  - Works with any network from `hardhat.config.ts`

- [ ] `scripts/demo-flow.ts`
  - Full lifecycle using simulated accounts on `hardhatMainnet`
  - Readable console output for live pitch demo
  - Each step: actor, action, batch id, tx hash

**Verification before proceeding:**

```bash
hardhat run scripts/deploy.ts --network hardhatMainnet
```

---

### Phase 5 — Documentation and Inspection Artifacts

- [ ] `docs/domain-model.md`
- [ ] `docs/architecture.md`
- [ ] `docs/security-notes.md`
- [ ] `docs/sequence-diagram.md`
- [ ] `inspection/checklist.md`
- [ ] `inspection/threat-model.md`
- [ ] `inspection/decisions.md`

**Verification:** manual review of completeness against the final contract.

---

### Final — Full Review + Real Network Deploy

- [ ] Complete audit of all contracts, tests, scripts, and artifacts
- [ ] Deploy to Sepolia — verify all transactions
- [ ] Deploy to mainnet

---

## Key Conventions (enforced throughout)

- `pragma solidity ^0.8.20;` on all contracts
- Custom errors only — no `require("string")`
- NatSpec (`@title`, `@author`, `@notice`, `@dev`, `@param`, `@return`) on every contract and function
- Events on every state transition
- `address(0)` validation on all address parameters
- Checks-Effects-Interactions pattern
- No `tx.origin` for authorization
- Named constants — no magic numbers
- OpenZeppelin: `AccessControl`, `Pausable`, `ReentrancyGuard`

## npm Scripts Reference

| Command                | Purpose                           |
| ---------------------- | --------------------------------- |
| `npm run compile`      | Hardhat compile                   |
| `npm run test`         | All tests (Solidity + TypeScript) |
| `npm run test:sol`     | Solidity/Forge tests only         |
| `npm run test:ts`      | TypeScript/viem tests only        |
| `npm run coverage`     | Tests with coverage report        |
| `npm run lint:sol`     | Solhint on `contracts/`           |
| `npm run typecheck`    | TypeScript type check             |
| `npm run format`       | Prettier write                    |
| `npm run format:check` | Prettier check                    |
| `npm run clean`        | Hardhat clean                     |
