// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ISupplyChainDemo} from "./interfaces/ISupplyChainDemo.sol";
import {SupplyChainErrors} from "./libraries/SupplyChainErrors.sol";

contract SupplyChainDemo is ISupplyChainDemo {
    mapping(bytes32 => Batch) private _batches;

    function _hasBatch(bytes32 batchId) private view returns (bool) {
        return _batches[batchId].createdAt != 0;
    }

    function hasBatch(bytes32 batchId) external view override returns (bool) {
        return _hasBatch(batchId);
    }

    function getBatch(bytes32 batchId) external view override returns (Batch memory) {
        if (!_hasBatch(batchId)) {
            revert SupplyChainErrors.BatchNotFound(batchId);
        }

        return _batches[batchId];
    }

    function createBatch(bytes32 batchId, address receiver) external override {
        if (receiver == address(0)) {
            revert SupplyChainErrors.InvalidAddress(receiver);
        }

        if (_hasBatch(batchId)) {
            revert SupplyChainErrors.BatchAlreadyExists(batchId);
        }

        _batches[batchId] = Batch({
            batchId: batchId,
            manufacturer: msg.sender,
            auditor: address(0),
            carrier: address(0),
            receiver: receiver,
            status: BatchStatus.Created,
            auditHash: bytes32(0),
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        emit BatchCreated(batchId, msg.sender, receiver);
    }
}
