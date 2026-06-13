# supply-chain-demo

A study-oriented repository focused on the blockchain domain of a supply chain flow.

## Overview

This repository contains the smart contract layer of a supply chain demo project. It is intended to demonstrate how blockchain can be used to represent critical supply chain events such as batch registration, audit anchoring, custody transfer, and delivery confirmation.

The repository is limited to the blockchain scope and related technical artifacts.

## Scope

This repository includes:

- smart contracts
- deployment scripts
- automated tests
- technical documentation
- software inspection artifacts

## Purpose

The goal of this project is to study and demonstrate how blockchain can complement a traditional supply chain model by recording critical events and anchoring off-chain artifacts through hashes.

## Main Concepts

The blockchain layer in this project is expected to cover:

- batch registration
- audit anchoring
- custody transfer
- delivery confirmation
- critical state transitions
- event traceability

## Verification Model

A key concept in this repository is future verification of off-chain artifacts.

The expected flow is:

1. retrieve an off-chain artifact
2. recalculate its hash
3. compare it with the hash anchored on-chain
4. verify whether the artifact remains unchanged

## Repository Structure

```text
supply-chain-demo/
  contracts/
  scripts/
  test/
  docs/
  inspection/
  README.md
```

## Audience

This repository is intended for:

- blockchain developers
- software architects
- engineering teams
- students and researchers