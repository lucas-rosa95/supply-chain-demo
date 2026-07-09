// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @title ISupplyChainDemo
/// @notice Interface for the SupplyChainDemo contract.
interface ISupplyChainDemo {
    enum BatchStatus {
        Created,
        Audited,
        InTransit,
        Delivered,
        Blocked
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
    }

    event BatchCreated(bytes32 indexed batchId, address indexed manufacturer, uint256 timestamp);
    event AuditLinked(
        bytes32 indexed batchId,
        address indexed auditor,
        bytes32 auditHash,
        uint256 timestamp
    );
    event CustodyPassed(bytes32 indexed batchId, address indexed carrier, uint256 timestamp);
    event DeliveryConfirmed(bytes32 indexed batchId, address indexed receiver, uint256 timestamp);
    event BatchBlocked(bytes32 indexed batchId, address indexed blockerBy, uint256 timestamp);
    event BatchUnblocked(bytes32 indexed batchId, address indexed unblockerBy, uint256 timestamp);

    function createBatch(bytes32 batchId, address receiver) external;

    function linkAudit(bytes32 batchId, bytes32 auditHash) external;

    function passCustody(bytes32 batchId, address carrier) external;

    function confirmDelivery(bytes32 batchId) external;

    function blockBatch(bytes32 batchId) external;

    function unblockBatch(bytes32 batchId) external;

    function getBatch(bytes32 batchId) external view returns (Batch memory);

    function hasBatch(bytes32 batchId) external view returns (bool);
}
