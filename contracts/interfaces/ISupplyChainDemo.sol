// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @title ISupplyChainDemo
/// @notice Interface for the SupplyChainDemo contract.
interface ISupplyChainDemo {
    enum BatchStatus {
        Created,
        Audited,
        InTransit,
        Delivered
    }

    /// @notice record of a supply chain batch
    struct Batch {
        bytes32 batchId;
        address manufacturer;
        address auditor;
        address carrier;
        address receiver;
        BatchStatus status;
        bytes32 auditHash;
        uint256 createdAt;
        uint256 updatedAt;
        bool blocked;
    }

    event BatchCreated(
        bytes32 indexed batchId,
        address indexed manufacturer,
        address indexed receiver,
        address carrier,
        address auditor
    );
    event AuditAnchored(bytes32 indexed batchId, address indexed auditor, bytes32 auditHash);
    event CustodyPassed(bytes32 indexed batchId, address indexed carrier);
    event DeliveryConfirmed(bytes32 indexed batchId, address indexed receiver);
    event BatchBlocked(bytes32 indexed batchId, address indexed blockedBy);
    event BatchUnblocked(bytes32 indexed batchId, address indexed unblockedBy);

    function createBatch(
        bytes32 batchId,
        address receiver,
        address carrier,
        address auditor
    ) external;

    function anchorAudit(bytes32 batchId, bytes32 auditHash) external;

    function passCustody(bytes32 batchId) external;

    function confirmDelivery(bytes32 batchId) external;

    function blockBatch(bytes32 batchId) external;

    function unblockBatch(bytes32 batchId) external;

    function getBatch(bytes32 batchId) external view returns (Batch memory);

    function hasBatch(bytes32 batchId) external view returns (bool);
}
