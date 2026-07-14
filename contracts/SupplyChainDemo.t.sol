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
    address internal otherReceiver = makeAddr("otherReceiver");
    address internal carrier = makeAddr("carrier");
    address internal otherCarrier = makeAddr("otherCarrier");
    address internal stranger = makeAddr("stranger");
    address internal auditor = makeAddr("auditor");
    address internal otherAuditor = makeAddr("otherAuditor");

    bytes32 internal constant BATCH_ID = keccak256("BATCH-001");
    bytes32 internal constant AUDIT_HASH = keccak256("AUDIT-001");

    // events must be redeclared to use vm.expectEmit
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

    function setUp() public {
        demo = new SupplyChainDemo(admin);

        // admin grants the domain roles. startPrank/stopPrank keeps `admin` as the
        // sender for the whole block — including the role-getter calls, which would
        // otherwise consume a single vm.prank and leave grantRole running as the test.
        vm.startPrank(admin);
        demo.grantRole(demo.MANUFACTURER_ROLE(), manufacturer);
        demo.grantRole(demo.AUDITOR_ROLE(), auditor);
        demo.grantRole(demo.AUDITOR_ROLE(), otherAuditor); // second auditor, not the designated one
        demo.grantRole(demo.CARRIER_ROLE(), carrier);
        demo.grantRole(demo.CARRIER_ROLE(), otherCarrier); // second carrier, not the designated one
        demo.grantRole(demo.RECEIVER_ROLE(), receiver);
        demo.grantRole(demo.RECEIVER_ROLE(), otherReceiver); // second receiver, not the designated one
        vm.stopPrank();
    }

    // --- createBatch ---

    function test_CreateBatch_Success() public {
        vm.expectEmit(true, true, true, true);
        emit BatchCreated(BATCH_ID, manufacturer, receiver, carrier, auditor);

        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);

        ISupplyChainDemo.Batch memory batch = demo.getBatch(BATCH_ID);
        assertEq(batch.batchId, BATCH_ID);
        assertEq(batch.manufacturer, manufacturer);
        assertEq(batch.receiver, receiver);
        assertEq(batch.carrier, carrier);
        assertEq(batch.auditor, auditor);
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
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);
    }

    function test_CreateBatch_RevertWhen_ReceiverIsZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(SupplyChainErrors.InvalidAddress.selector, address(0))
        );
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, address(0), carrier, auditor);
    }

    function test_CreateBatch_RevertWhen_CarrierIsZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(SupplyChainErrors.InvalidAddress.selector, address(0))
        );
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, address(0), auditor);
    }

    function test_CreateBatch_RevertWhen_AuditorIsZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(SupplyChainErrors.InvalidAddress.selector, address(0))
        );
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, address(0));
    }

    function test_CreateBatch_RevertWhen_DuplicateId() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);

        vm.expectRevert(
            abi.encodeWithSelector(SupplyChainErrors.BatchAlreadyExists.selector, BATCH_ID)
        );
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);
    }

    // --- anchorAudit ---

    function test_AnchorAudit_Success() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);

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
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);

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

    function test_AnchorAudit_RevertWhen_NotDesignatedAuditor() public {
        // batch designates `auditor`; otherAuditor has the role but is not the designated one
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainErrors.Unauthorized.selector,
                otherAuditor,
                demo.AUDITOR_ROLE()
            )
        );
        vm.prank(otherAuditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);
    }

    function test_AnchorAudit_RevertWhen_BatchNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(SupplyChainErrors.BatchNotFound.selector, BATCH_ID));
        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);
    }

    function test_AnchorAudit_RevertWhen_WrongStatus() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);

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

    // --- passCustody ---

    function test_PassCustody_Success() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);

        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);

        vm.expectEmit(true, true, false, false);
        emit CustodyPassed(BATCH_ID, carrier);

        vm.prank(carrier);
        demo.passCustody(BATCH_ID);

        ISupplyChainDemo.Batch memory batch = demo.getBatch(BATCH_ID);
        assertEq(uint256(batch.status), uint256(ISupplyChainDemo.BatchStatus.InTransit));
        assertEq(batch.carrier, carrier);
    }

    function test_PassCustody_RevertWhen_Unauthorized() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);

        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainErrors.Unauthorized.selector,
                stranger,
                demo.CARRIER_ROLE()
            )
        );
        vm.prank(stranger);
        demo.passCustody(BATCH_ID);
    }

    function test_PassCustody_RevertWhen_NotDesignatedCarrier() public {
        // batch designates `carrier`; otherCarrier has the role but is not the designated one
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);

        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainErrors.Unauthorized.selector,
                otherCarrier,
                demo.CARRIER_ROLE()
            )
        );
        vm.prank(otherCarrier);
        demo.passCustody(BATCH_ID);
    }

    function test_PassCustody_RevertWhen_BatchNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(SupplyChainErrors.BatchNotFound.selector, BATCH_ID));
        vm.prank(carrier);
        demo.passCustody(BATCH_ID);
    }

    function test_PassCustody_RevertWhen_WrongStatus() public {
        // created but not audited yet: status is Created, not Audited
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainErrors.InvalidBatchStatus.selector,
                BATCH_ID,
                ISupplyChainDemo.BatchStatus.Created, // current
                ISupplyChainDemo.BatchStatus.Audited // expected
            )
        );
        vm.prank(carrier);
        demo.passCustody(BATCH_ID);
    }

    // --- confirmDelivery ---

    function test_ConfirmDelivery_Success() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);
        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);
        vm.prank(carrier);
        demo.passCustody(BATCH_ID);

        vm.expectEmit(true, true, false, false);
        emit DeliveryConfirmed(BATCH_ID, receiver);

        vm.prank(receiver);
        demo.confirmDelivery(BATCH_ID);

        ISupplyChainDemo.Batch memory batch = demo.getBatch(BATCH_ID);
        assertEq(uint256(batch.status), uint256(ISupplyChainDemo.BatchStatus.Delivered));
        assertEq(batch.receiver, receiver);
    }

    function test_ConfirmDelivery_RevertWhen_Unauthorized() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);
        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);
        vm.prank(carrier);
        demo.passCustody(BATCH_ID);

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainErrors.Unauthorized.selector,
                stranger,
                demo.RECEIVER_ROLE()
            )
        );
        vm.prank(stranger);
        demo.confirmDelivery(BATCH_ID);
    }

    function test_ConfirmDelivery_RevertWhen_NotDesignatedReceiver() public {
        // batch designates `receiver`; otherReceiver has the role but is not the designated one
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);
        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);
        vm.prank(carrier);
        demo.passCustody(BATCH_ID);

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainErrors.Unauthorized.selector,
                otherReceiver,
                demo.RECEIVER_ROLE()
            )
        );
        vm.prank(otherReceiver);
        demo.confirmDelivery(BATCH_ID);
    }

    function test_ConfirmDelivery_RevertWhen_BatchNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(SupplyChainErrors.BatchNotFound.selector, BATCH_ID));
        vm.prank(receiver);
        demo.confirmDelivery(BATCH_ID);
    }

    function test_ConfirmDelivery_RevertWhen_WrongStatus() public {
        // audited but not yet in transit: status is Audited, not InTransit
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);
        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainErrors.InvalidBatchStatus.selector,
                BATCH_ID,
                ISupplyChainDemo.BatchStatus.Audited, // current
                ISupplyChainDemo.BatchStatus.InTransit // expected
            )
        );
        vm.prank(receiver);
        demo.confirmDelivery(BATCH_ID);
    }

    // --- blockBatch ---

    function test_BlockBatch_Success() public {
        // reach Audited to prove the real status is preserved while blocked
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);
        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);

        vm.expectEmit(true, true, false, false);
        emit BatchBlocked(BATCH_ID, admin);

        vm.prank(admin);
        demo.blockBatch(BATCH_ID);

        ISupplyChainDemo.Batch memory batch = demo.getBatch(BATCH_ID);
        assertTrue(batch.blocked);
        // status is preserved (not overwritten): still Audited
        assertEq(uint256(batch.status), uint256(ISupplyChainDemo.BatchStatus.Audited));
    }

    function test_BlockBatch_RevertWhen_Unauthorized() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainErrors.Unauthorized.selector,
                stranger,
                demo.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(stranger);
        demo.blockBatch(BATCH_ID);
    }

    function test_BlockBatch_RevertWhen_BatchNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(SupplyChainErrors.BatchNotFound.selector, BATCH_ID));
        vm.prank(admin);
        demo.blockBatch(BATCH_ID);
    }

    function test_BlockBatch_RevertWhen_AlreadyBlocked() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);

        vm.prank(admin);
        demo.blockBatch(BATCH_ID);

        vm.expectRevert(abi.encodeWithSelector(SupplyChainErrors.BatchIsBlocked.selector, BATCH_ID));
        vm.prank(admin);
        demo.blockBatch(BATCH_ID);
    }

    // --- unblockBatch ---

    function test_UnblockBatch_Success() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);
        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);

        vm.prank(admin);
        demo.blockBatch(BATCH_ID);

        vm.expectEmit(true, true, false, false);
        emit BatchUnblocked(BATCH_ID, admin);

        vm.prank(admin);
        demo.unblockBatch(BATCH_ID);

        ISupplyChainDemo.Batch memory batch = demo.getBatch(BATCH_ID);
        assertFalse(batch.blocked);
        // status restored automatically (it was never overwritten): still Audited
        assertEq(uint256(batch.status), uint256(ISupplyChainDemo.BatchStatus.Audited));
    }

    function test_UnblockBatch_RevertWhen_Unauthorized() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);
        vm.prank(admin);
        demo.blockBatch(BATCH_ID);

        vm.expectRevert(
            abi.encodeWithSelector(
                SupplyChainErrors.Unauthorized.selector,
                stranger,
                demo.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(stranger);
        demo.unblockBatch(BATCH_ID);
    }

    function test_UnblockBatch_RevertWhen_BatchNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(SupplyChainErrors.BatchNotFound.selector, BATCH_ID));
        vm.prank(admin);
        demo.unblockBatch(BATCH_ID);
    }

    function test_UnblockBatch_RevertWhen_NotBlocked() public {
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);

        vm.expectRevert(abi.encodeWithSelector(SupplyChainErrors.BatchNotBlocked.selector, BATCH_ID));
        vm.prank(admin);
        demo.unblockBatch(BATCH_ID);
    }

    // --- _requireNotBlocked guard on transitions ---

    function test_Transition_RevertWhen_Blocked() public {
        // batch is in Created (the right status for anchorAudit); only the block stops it
        vm.prank(manufacturer);
        demo.createBatch(BATCH_ID, receiver, carrier, auditor);

        vm.prank(admin);
        demo.blockBatch(BATCH_ID);

        vm.expectRevert(abi.encodeWithSelector(SupplyChainErrors.BatchIsBlocked.selector, BATCH_ID));
        vm.prank(auditor);
        demo.anchorAudit(BATCH_ID, AUDIT_HASH);
    }
}
