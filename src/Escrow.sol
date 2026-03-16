// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IEscrow.sol";

contract Escrow is IEscrow {
    address public override buyer;
    address public override seller;
    address public override arbiter;
    uint256 public override amount;
    State public override state;

    bool public override approvedByBuyer;
    bool public override approvedBySeller;

    error OnlyBuyer();
    error OnlySeller();
    error OnlyParty();
    error OnlyArbiter();
    error InvalidState(State expected, State actual);
    error WrongDepositAmount(uint256 expected, uint256 actual);
    error AlreadyApproved();
    error ZeroAddressNotAllowed();

    constructor(
        address _buyer,
        address _seller,
        address _arbiter,
        uint256 _amount
    ) {
        if (_buyer == address(0) || _seller == address(0) || _arbiter == address(0)) {
            revert ZeroAddressNotAllowed();
        }

        buyer = _buyer;
        seller = _seller;
        arbiter = _arbiter;
        amount = _amount;
        state = State.AWAITING_FUNDING;
    }

    modifier onlyBuyer() {
        if (msg.sender != buyer) revert OnlyBuyer();
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller) revert OnlySeller();
        _;
    }

    modifier onlyParty() {
        if (msg.sender != buyer && msg.sender != seller) revert OnlyParty();
        _;
    }

    modifier onlyArbiter() {
        if (msg.sender != arbiter) revert OnlyArbiter();
        _;
    }

    modifier inState(State expected) {
        if (state != expected) revert InvalidState(expected, state);
        _;
    }

    function fund()
        external
        payable
        override
        onlyBuyer
        inState(State.AWAITING_FUNDING)
    {
        if (msg.value != amount) {
            revert WrongDepositAmount(amount, msg.value);
        }

        state = State.FUNDED;
        emit Funded(msg.sender, msg.value);
    }

    function approve()
        external
        override
        onlyParty
        inState(State.FUNDED)
    {
        if (msg.sender == buyer) {
            if (approvedByBuyer) revert AlreadyApproved();
            approvedByBuyer = true;
        } else {
            if (approvedBySeller) revert AlreadyApproved();
            approvedBySeller = true;
        }

        emit Approved(msg.sender);

        if (approvedByBuyer && approvedBySeller) {
            _releaseToSeller();
        }
    }

    function raiseDispute()
        external
        override
        onlyParty
        inState(State.FUNDED)
    {
        state = State.DISPUTED;
        emit DisputeRaised(msg.sender);
    }

    function resolveDispute(bool releaseToSeller)
        external
        override
        onlyArbiter
        inState(State.DISPUTED)
    {
        if (releaseToSeller) {
            _releaseToSeller();
        } else {
            _refundBuyer();
        }

        emit DisputeResolved(msg.sender, releaseToSeller);
    }

    function _releaseToSeller() internal {
        state = State.COMPLETE;

        uint256 bal = address(this).balance;
        (bool ok, ) = payable(seller).call{value: bal}("");
        require(ok, "Transfer to seller failed");

        emit Released(seller, bal);
    }

    function _refundBuyer() internal {
        state = State.REFUNDED;

        uint256 bal = address(this).balance;
        (bool ok, ) = payable(buyer).call{value: bal}("");
        require(ok, "Refund to buyer failed");

        emit Refunded(buyer, bal);
    }
}