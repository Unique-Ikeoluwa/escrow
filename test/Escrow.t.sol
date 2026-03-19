// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Escrow.sol";

contract EscrowTest is Test {
    Escrow escrow;

    address buyer = address(1);
    address seller = address(2);
    address arbiter = address(3);
    address stranger = address(4);

    uint256 constant ESCROW_AMOUNT = 1 ether;

    function setUp() public {
        vm.deal(buyer, 10 ether);
        vm.deal(seller, 10 ether);
        vm.deal(arbiter, 10 ether);
        vm.deal(stranger, 10 ether);

        escrow = new Escrow(buyer, seller, arbiter, ESCROW_AMOUNT);
    }

    function testInitialStateIsAwaitingFunding() public {
        assertEq(uint256(escrow.state()), uint256(IEscrow.State.AWAITING_FUNDING));
    }

    function testInitialAddressesSetCorrectly() public {
        assertEq(escrow.buyer(), buyer);
        assertEq(escrow.seller(), seller);
        assertEq(escrow.arbiter(), arbiter);
        assertEq(escrow.amount(), ESCROW_AMOUNT);
    }

    function testOnlyBuyerCanFund() public {
        vm.prank(stranger);
        vm.expectRevert(Escrow.OnlyBuyer.selector);
        escrow.fund{value: ESCROW_AMOUNT}();
    }

    function testBuyerMustFundExactAmount() public {
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Escrow.WrongDepositAmount.selector, ESCROW_AMOUNT, 0.5 ether));
        escrow.fund{value: 0.5 ether}();
    }

    function testBuyerCanFundSuccessfully() public {
        vm.prank(buyer);
        escrow.fund{value: ESCROW_AMOUNT}();

        assertEq(uint256(escrow.state()), uint256(IEscrow.State.FUNDED));
        assertEq(address(escrow).balance, ESCROW_AMOUNT);
    }

    function testCannotFundTwice() public {
        vm.prank(buyer);
        escrow.fund{value: ESCROW_AMOUNT}();

        vm.prank(buyer);
        vm.expectRevert();
        escrow.fund{value: ESCROW_AMOUNT}();
    }

    function testOnlyBuyerOrSellerCanApprove() public {
        vm.prank(buyer);
        escrow.fund{value: ESCROW_AMOUNT}();

        vm.prank(stranger);
        vm.expectRevert(Escrow.OnlyParty.selector);
        escrow.approve();
    }

    function testBuyerApprovalWorks() public {
        vm.prank(buyer);
        escrow.fund{value: ESCROW_AMOUNT}();

        vm.prank(buyer);
        escrow.approve();

        assertTrue(escrow.approvedByBuyer());
        assertFalse(escrow.approvedBySeller());
        assertEq(uint256(escrow.state()), uint256(IEscrow.State.FUNDED));
    }

    function testSellerApprovalWorks() public {
        vm.prank(buyer);
        escrow.fund{value: ESCROW_AMOUNT}();

        vm.prank(seller);
        escrow.approve();

        assertTrue(escrow.approvedBySeller());
        assertFalse(escrow.approvedByBuyer());
    }

    function testSamePartyCannotApproveTwice() public {
        vm.prank(buyer);
        escrow.fund{value: ESCROW_AMOUNT}();

        vm.prank(buyer);
        escrow.approve();

        vm.prank(buyer);
        vm.expectRevert(Escrow.AlreadyApproved.selector);
        escrow.approve();
    }

    function testBothApprovalsReleaseFundsToSeller() public {
        vm.prank(buyer);
        escrow.fund{value: ESCROW_AMOUNT}();

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(buyer);
        escrow.approve();

        vm.prank(seller);
        escrow.approve();

        assertEq(uint256(escrow.state()), uint256(IEscrow.State.COMPLETE));
        assertEq(address(escrow).balance, 0);
        assertEq(seller.balance, sellerBalanceBefore + ESCROW_AMOUNT);
    }

    function testBuyerOrSellerCanRaiseDispute() public {
        vm.prank(buyer);
        escrow.fund{value: ESCROW_AMOUNT}();

        vm.prank(seller);
        escrow.raiseDispute();

        assertEq(uint256(escrow.state()), uint256(IEscrow.State.DISPUTED));
    }

    function testOnlyArbiterCanResolveDispute() public {
        vm.prank(buyer);
        escrow.fund{value: ESCROW_AMOUNT}();

        vm.prank(buyer);
        escrow.raiseDispute();

        vm.prank(stranger);
        vm.expectRevert(Escrow.OnlyArbiter.selector);
        escrow.resolveDispute(true);
    }

    function testArbiterCanReleaseFundsToSeller() public {
        vm.prank(buyer);
        escrow.fund{value: ESCROW_AMOUNT}();

        vm.prank(buyer);
        escrow.raiseDispute();

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(arbiter);
        escrow.resolveDispute(true);

        assertEq(uint256(escrow.state()), uint256(IEscrow.State.COMPLETE));
        assertEq(address(escrow).balance, 0);
        assertEq(seller.balance, sellerBalanceBefore + ESCROW_AMOUNT);
    }

    function testArbiterCanRefundBuyer() public {
        vm.prank(buyer);
        escrow.fund{value: ESCROW_AMOUNT}();

        vm.prank(seller);
        escrow.raiseDispute();

        uint256 buyerBalanceBefore = buyer.balance;

        vm.prank(arbiter);
        escrow.resolveDispute(false);

        assertEq(uint256(escrow.state()), uint256(IEscrow.State.REFUNDED));
        assertEq(address(escrow).balance, 0);
        assertEq(buyer.balance, buyerBalanceBefore + ESCROW_AMOUNT);
    }
}
