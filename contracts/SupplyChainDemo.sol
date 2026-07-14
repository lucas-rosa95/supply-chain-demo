// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ISupplyChainDemo} from "./interfaces/ISupplyChainDemo.sol";
import {SupplyChainErrors} from "./libraries/SupplyChainErrors.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract SupplyChainDemo is ISupplyChainDemo, AccessControl {
    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant CARRIER_ROLE = keccak256("CARRIER_ROLE");
    bytes32 public constant RECEIVER_ROLE = keccak256("RECEIVER_ROLE");

    mapping(bytes32 => Batch) private _batches;

    constructor(address admin) {
        if (admin == address(0)) {
            revert SupplyChainErrors.InvalidAddress(admin);
        }

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function _hasBatch(bytes32 batchId) private view returns (bool) {
        return _batches[batchId].createdAt != 0;
    }

    function _requireRole(bytes32 role) private view {
        if (!hasRole(role, msg.sender)) {
            revert SupplyChainErrors.Unauthorized(msg.sender, role);
        }
    }

    function _requireExists(bytes32 batchId) private view {
        if (!_hasBatch(batchId)) {
            revert SupplyChainErrors.BatchNotFound(batchId);
        }
    }

    function _requireStatus(bytes32 batchId, BatchStatus expected) private view {
        BatchStatus current = _batches[batchId].status;

        if (current != expected) {
            revert SupplyChainErrors.InvalidBatchStatus(batchId, current, expected);
        }
    }

    function hasBatch(bytes32 batchId) external view override returns (bool) {
        return _hasBatch(batchId);
    }

    function getBatch(bytes32 batchId) external view override returns (Batch memory) {
        _requireExists(batchId);

        return _batches[batchId];
    }

    function createBatch(
        bytes32 batchId,
        address receiver,
        address carrier,
        address auditor
    ) external override {
        _requireRole(MANUFACTURER_ROLE);

        if (receiver == address(0)) {
            revert SupplyChainErrors.InvalidAddress(receiver);
        }

        if (carrier == address(0)) {
            revert SupplyChainErrors.InvalidAddress(carrier);
        }

        if (auditor == address(0)) {
            revert SupplyChainErrors.InvalidAddress(auditor);
        }

        if (_hasBatch(batchId)) {
            revert SupplyChainErrors.BatchAlreadyExists(batchId);
        }

        _batches[batchId] = Batch({
            batchId: batchId,
            manufacturer: msg.sender,
            auditor: auditor,
            carrier: carrier,
            receiver: receiver,
            status: BatchStatus.Created,
            auditHash: bytes32(0),
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        emit BatchCreated(batchId, msg.sender, receiver, carrier, auditor);
    }

    function anchorAudit(bytes32 batchId, bytes32 auditHash) external override {
        _requireRole(AUDITOR_ROLE);
        _requireExists(batchId);

        Batch storage batch = _batches[batchId];

        if (batch.auditor != msg.sender) {
            revert SupplyChainErrors.Unauthorized(msg.sender, AUDITOR_ROLE);
        }

        _requireStatus(batchId, BatchStatus.Created);

        batch.auditHash = auditHash;
        batch.status = BatchStatus.Audited;
        batch.updatedAt = block.timestamp;

        emit AuditAnchored(batchId, msg.sender, auditHash);
    }

    function passCustody(bytes32 batchId) external override {
        _requireRole(CARRIER_ROLE);
        _requireExists(batchId);

        Batch storage batch = _batches[batchId];

        if (batch.carrier != msg.sender) {
            revert SupplyChainErrors.Unauthorized(msg.sender, CARRIER_ROLE);
        }

        _requireStatus(batchId, BatchStatus.Audited);

        batch.status = BatchStatus.InTransit;
        batch.updatedAt = block.timestamp;

        emit CustodyPassed(batchId, msg.sender);
    }
}
