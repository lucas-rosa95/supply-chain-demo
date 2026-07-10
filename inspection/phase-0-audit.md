# Phase 0 Audit — Foundation Alignment

| Field    | Value                                                                 |
| -------- | --------------------------------------------------------------------- |
| Phase    | 0 — Align foundation                                                  |
| Date     | 2026-07-10                                                            |
| Scope    | `contracts/**/*.sol`, `hardhat.config.ts`, `LICENSE`, `package.json`  |
| Toolchain| Hardhat 3 · solc 0.8.35 · solhint 6.2.1 (run inside container `supply-app`) |
| Result   | ✅ **PASS** — foundation is aligned, compiles and lints clean         |

## Summary

The compiler version, source `pragma` directives, and the solhint compiler-version rule are all aligned
at `0.8.35`. Every Solidity source declares a license (`SPDX-License-Identifier`) and a compatible
`pragma`. The project compiles with zero warnings and lints clean. The interface and errors library were
reviewed and their naming/semantics settled. No blocking issues found.

## Method

All checks were run inside the project container (`docker compose exec app …`), the only environment
that carries the toolchain. Commands used for validation:

```bash
docker compose exec app npm run clean     # force a from-scratch build (cold cache)
docker compose exec app npm run compile   # hardhat compile
docker compose exec app npm run lint:sol  # solhint contracts/**/*.sol
```

The `pragma`/`SPDX` inventory below was produced by scanning every `.sol` file under `contracts/`.

## Checks

### C1 — Compiler ↔ pragma ↔ solhint alignment

- [x] `hardhat.config.ts` pins `version: "0.8.35"` in both the `default` and `production` profiles.
- [x] Every source `pragma` (`^0.8.35`) is satisfied by solc `0.8.35`.
- [x] solhint's `compiler-version` rule reports no violation.

### C2 — `SPDX` and `pragma` presence & compliance

- [x] Every `.sol` file declares an `SPDX-License-Identifier`.
- [x] Every `.sol` file declares a `pragma` compatible with the configured compiler.

**Inventory (evidence):**

| File                                        | SPDX  | Pragma      | Compliant with `0.8.35` |
| ------------------------------------------- | ----- | ----------- | ----------------------- |
| `contracts/interfaces/ISupplyChainDemo.sol` | `MIT` | `^0.8.35`   | ✅                      |
| `contracts/libraries/SupplyChainErrors.sol` | `MIT` | `^0.8.35`   | ✅                      |
| `contracts/SupplyChainDemo.sol`             | `MIT` | `^0.8.35`   | ✅                      |
| `contracts/SupplyChainDemo.t.sol`           | `MIT` | `^0.8.35`   | ✅                      |

**Command output (evidence):**

```
$ npm run compile
Compiled 4 Solidity files with solc 0.8.35
# (no warnings)

$ npm run lint:sol
# (no output; exit code 0)
```

> Note: `SupplyChainDemo.sol` and `SupplyChainDemo.t.sol` are intentional empty stubs (license + pragma
> only) reserved for Phases 1 and 2. They are compliant today; their contract/test bodies land later.

### C3 — Interface & errors: naming and semantics review

- [x] Events dropped the explicit `timestamp` parameter — consumers read `block.timestamp` from the
  log's block, avoiding a redundant, gas-costing field.
- [x] Renamed `linkAudit` / `AuditLinked` → `anchorAudit` / `AuditAnchored`, aligning the code with the
  domain language ("anchor the audit hash").
- [x] Block/unblock event actor parameters renamed to `blockedBy` / `unblockedBy` (grammatical
  correctness and consistency with the other events' actor fields).
- [x] Added custom error `BatchAlreadyBlocked(bytes32)` for the multi-source `blockBatch` case; the
  single-source transitions keep `InvalidBatchStatus(id, current, expected)`.

### C4 — Implementation convention (recorded decision)

- [x] **No on-chain state-machine table.** With a small, fixed lifecycle (5 statuses), allowed
  transitions are enforced imperatively via a single `private view` helper (`_requireStatus`), which
  satisfies the rules and saves gas versus a stored transition graph. The state graph will be
  **documented** (not stored on-chain) in Phase 5. Recorded in `AGENTS.md` and `ROADMAP.md`.

### C5 — License backing

- [x] The `MIT` SPDX identifier declared in every `.sol` is now backed at the project level.
- [x] `LICENSE` file present (MIT text, `Copyright (c) 2026 Lucas Rosa`).
- [x] `package.json` declares `"license": "MIT"`.
- [x] License chosen (MIT) is compatible with the project's dependencies (OpenZeppelin Contracts v5 is
  also MIT). Intent: open reference/study project.

## Follow-ups

- None blocking. The compiler warnings observed earlier in the phase disappeared once the stub files
  received their `SPDX` + `pragma` headers.
