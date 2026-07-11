// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {SupplyChainDemo} from "./SupplyChainDemo.sol";
import {ISupplyChainDemo} from "./interfaces/ISupplyChainDemo.sol";
import {SupplyChainErrors} from "./libraries/SupplyChainErrors.sol";

contract SupplyChainDemoTest is Test {
    SupplyChainDemo internal demo;

    address internal admin = makeAddr("admin");
    address internal manufacturer = makeAddr("manufacturer");
    address internal receiver = makeAddr("receiver");
    address internal stranger = makeAddr("stranger");
    address internal auditor = makeAddr("auditor");

    bytes32 internal constant BATCH_ID = keccak256("BATCH-001");
    bytes32 internal constant AUDIT_HASH = keccak256("AUDIT-001");

    // events must be redeclared to use vm.expectEmit
    event BatchCreated(
        bytes32 indexed batchId,
        address indexed manufacturer,
        address indexed receiver
    );
    event AuditAnchored(bytes32 indexed batchId, address indexed auditor, bytes32 auditHash);

    function setUp() public {
        demo = new SupplyChainDemo(admin);

        // admin grants the manufacturer role
        vm.prank(admin);
        demo.grantRole(demo.MANUFACTURER_ROLE(), manufacturer);

        // admin grants the auditor role
        vm.prank(admin);
        demo.grantRole(demo.AUDITOR_ROLE(), auditor);
    }

    // --- createBatch ---

    function test_CreateBatch_Success() public {
        vm.expectEmit(true, true, true, false);
        emit BatchCreated(BATCH_ID, manufacturer, receiver);

        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver);

        ISupplyChainDemo.Batch memory batch = demo.getBatch(BATCH_ID);
        assertEq(batch.batchId, BATCH_ID);
        assertEq(batch.manufacturer, manufacturer);
        assertEq(batch.receiver, receiver);
        assertEq(uint256(batch.status), uint256(ISupplyChainDemo.BatchStatus.Created));
        assertTrue(demo.hasBatch(BATCH_ID));
    }

    function test_CreateBatch_RevertWhen_Unauthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainErrors.Unauthorized.selector,
                stranger,
                demo.MANUFACTURER_ROLE()
            )
        );
        vm.prank(stranger);
        demo.createBatch(BATCH_ID, receiver);
    }

    function test_CreateBatch_RevertWhen_ReceiverIsZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(SupplyChainErrors.InvalidAddress.selector, address(0))
        );
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, address(0));
    }

    function test_CreateBatch_RevertWhen_DuplicateId() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver);

        vm.expectRevert(
            abi.encodeWithSelector(SupplyChainErrors.BatchAlreadyExists.selector, BATCH_ID)
        );
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver);
    }

    // --- anchorAudit ---

    function test_AnchorAudit_Success() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver);

        vm.expectEmit(true, true, false, true);
        emit AuditAnchored(BATCH_ID, auditor, AUDIT_HASH);

        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);

        ISupplyChainDemo.Batch memory batch = demo.getBatch(BATCH_ID);
        assertEq(uint256(batch.status), uint256(ISupplyChainDemo.BatchStatus.Audited));
        assertEq(batch.auditor, auditor);
        assertEq(batch.auditHash, AUDIT_HASH);
    }

    function test_AnchorAudit_RevertWhen_Unauthorized() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver);

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainErrors.Unauthorized.selector,
                stranger,
                demo.AUDITOR_ROLE()
            )
        );
        vm.prank(stranger);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);
    }

    function test_AnchorAudit_RevertWhen_BatchNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(SupplyChainErrors.BatchNotFound.selector, BATCH_ID));
        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);
    }

    function test_AnchorAudit_RevertWhen_WrongStatus() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver);

        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainErrors.InvalidBatchStatus.selector,
                BATCH_ID,
                ISupplyChainDemo.BatchStatus.Audited, // current
                ISupplyChainDemo.BatchStatus.Created // expected
            )
        );
        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);
    }
}
