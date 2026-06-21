// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISupplyChainDemo} from "../interfaces/ISupplyChainDemo.sol";

/// @title SupplyChainErrors
/// @notice Custom errors for the SupplyChainDemo contract.
library SupplyChainErrors {
    /// @dev Thrown when a batch with the given ID already exists.
    error BatchAlreadyExists(bytes32 batchId);
    /// @dev Thrown when a batch with the given ID does not exist.
    error BatchNotFound(bytes32 batchId);
    /// @dev Thrown when the caller is not authorized to perform an action.
    error Unauthorized(address caller, bytes32 role);
    /// @dev Thrown when a batch is in an invalid status for the requested operation.
    error InvalidBatchStatus(
        bytes32 batchId,
        ISupplyChainDemo.BatchStatus current,
        ISupplyChainDemo.BatchStatus expected
    );

    /// @dev Thrown when an address is invalid (e.g., zero address).
    error InvalidAddress(address addr);
}
