# Copilot Instructions — supply-chain-demo

## Project Overview

This repository is the **blockchain domain** of a supply chain demo project.

It is a study-oriented, pitch-quality project designed to demonstrate how smart contracts can be applied to a real-world supply chain flow. Although it is a mockup/demo, it must be developed with production-grade standards in mind, as it will be used for executive pitch and technical review.

This repository contains **only** the blockchain layer:

- Solidity smart contracts
- Hardhat deployment scripts
- Automated tests
- Technical documentation
- Software inspection artifacts

Frontend, backend API, and off-chain database layers are maintained in separate repositories.

---

## Architecture

### Hybrid model

- **Off-chain**: operational data, audit documents, user management, business details
- **On-chain**: critical events, state transitions, artifact hashes, custody records

### Core principle

> The full business artifact lives off-chain. Its integrity proof and critical event history are anchored on-chain.

---

## Domain Model

### Main entity

**Batch** — a supply chain lot that flows through the process.

### Actors and roles

| Role         | Responsibility                    |
| ------------ | --------------------------------- |
| Admin        | Authorize and manage participants |
| Manufacturer | Create and register batches       |
| Auditor      | Anchor audit results on-chain     |
| Carrier      | Receive and transfer custody      |
| Receiver     | Confirm final delivery            |

### Batch lifecycle states

```
Created → Audited → InTransit → Delivered
                              ↘ Blocked
```

### Critical on-chain events

- `BatchCreated`
- `AuditAnchored`
- `CustodyTransferred`
- `DeliveryConfirmed`
- `BatchBlocked`
- `BatchRecalled`

---

## Smart Contract Standards

### Solidity version

Always use `pragma solidity ^0.8.20;`

### OpenZeppelin dependencies

Prefer OpenZeppelin for:

- `AccessControl` — role management
- `Pausable` — emergency stop
- `ReentrancyGuard` — reentrancy protection

### Security rules — always enforce

- Use `custom errors` instead of string messages in `require`
- Explicit visibility on all functions and variables
- Never use `tx.origin` for authorization
- No magic numbers — use named constants
- Always emit events on state changes
- Validate all address parameters against `address(0)`
- Follow Checks-Effects-Interactions pattern

### NatSpec — required on all contracts and functions

```solidity
/// @title Contract title
/// @author supply-chain-demo
/// @notice External-facing description
/// @dev Internal technical notes
/// @param paramName Description
/// @return Description
```

### Custom errors pattern

```solidity
error BatchNotFound(string batchId);
error UnauthorizedActor(address caller, bytes32 role);
error InvalidBatchStatus(string batchId, BatchStatus current, BatchStatus required);
```

---

## Project Structure

```
supply-chain-demo/
  contracts/
    SupplyChainDemo.sol         # Main contract
    interfaces/
      ISupplyChainDemo.sol      # Contract interface
    libraries/
      SupplyChainErrors.sol     # Custom errors

  test/
    unit/
      SupplyChainDemo.test.ts
    integration/
      EndToEndFlow.test.ts

  scripts/
    deploy.ts
    demo-flow.ts

  docs/
    domain-model.md
    architecture.md
    security-notes.md
    sequence-diagram.md

  inspection/
    checklist.md
    threat-model.md
    decisions.md
```

---

## Testing Standards

### Coverage target

- Minimum 95% line and branch coverage on all contracts

### Required test categories

- Happy path flows
- Access control — all unauthorized calls must revert
- Invalid state transitions — must revert with correct custom errors
- Edge cases — zero address, empty values, duplicate IDs
- Event assertions — all events must be verified

### Test structure pattern

```typescript
describe("FunctionName", () => {
  context("when called by authorized actor", () => {
    it("should ...", async () => {});
  });
  context("when called by unauthorized actor", () => {
    it("should revert with UnauthorizedActor", async () => {});
  });
});
```

---

## Audit and Inspection

This project includes an `inspection/` folder with artifacts for:

- software inspection and technical review
- executive presentations
- architecture validation
- security analysis
- design decision documentation

When adding or changing contracts, update relevant inspection artifacts.

---

## Key Design Decisions

### Why a single contract for MVP?

The first version uses a single `SupplyChainDemo.sol` to keep the demo simple and presentation-friendly. Modular decomposition can be applied in later iterations.

### Why OpenZeppelin AccessControl over a custom owner pattern?

Role-based control is required from day one because the domain has multiple distinct actor types. A simple owner pattern is insufficient.

### Why off-chain document storage?

Full documents must not be stored on-chain due to cost, privacy, and size constraints. Only the hash of the signed artifact is anchored on-chain.

### Why hash the final signed artifact?

The anchored hash represents the final, signed version of the document. This ensures the integrity check covers both the content and the signature artifact.

---

## What Copilot Should Prioritize

When assisting with this project:

1. Always follow the security rules listed above
2. Always include NatSpec on new contracts and functions
3. Always use custom errors — never raw strings in require
4. Always emit events on state transitions
5. Always suggest tests alongside contract code
6. Prefer OpenZeppelin base contracts when applicable
7. Flag any pattern that could introduce reentrancy or access control issues
8. Keep contracts readable — this is a demo/pitch project

---

## Out of Scope for This Repository

- Frontend applications
- Backend REST APIs
- Database schemas
- Digital signature implementation
- Real certificate authority integration
- Production multi-node network setup
