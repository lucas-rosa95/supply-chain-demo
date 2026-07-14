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

    function setUp() public {
        demo = new SupplyChainDemo(admin);

        // admin grants the manufacturer role
        vm.prank(admin);
        demo.grantRole(demo.MANUFACTURER_ROLE(), manufacturer);

        // admin grants the auditor role
        vm.prank(admin);
        demo.grantRole(demo.AUDITOR_ROLE(), auditor);

        // admin grants the auditor role to a second auditor (not the designated one)
        vm.prank(admin);
        demo.grantRole(demo.AUDITOR_ROLE(), otherAuditor);

        // admin grants the carrier role
        vm.prank(admin);
        demo.grantRole(demo.CARRIER_ROLE(), carrier);

        // admin grants the carrier role to a second carrier (not the designated one)
        vm.prank(admin);
        demo.grantRole(demo.CARRIER_ROLE(), otherCarrier);
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
}
