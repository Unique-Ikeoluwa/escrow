// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IEscrow {
    enum State {
        AWAITING_FUNDING,
        FUNDED,
        DISPUTED,
        COMPLETE,
        REFUNDED
    }

    event Funded(address indexed buyer, uint256 amount);
    event Approved(address indexed approver);
    event Released(address indexed seller, uint256 amount);
    event Refunded(address indexed buyer, uint256 amount);
    event DisputeRaised(address indexed raisedBy);
    event DisputeResolved(address indexed resolver, bool releasedToSeller);

    function fund() external payable;
    function approve() external;
    function raiseDispute() external;
    function resolveDispute(bool releaseToSeller) external;

    function buyer() external view returns (address);
    function seller() external view returns (address);
    function arbiter() external view returns (address);
    function amount() external view returns (uint256);
    function state() external view returns (State);
    function approvedByBuyer() external view returns (bool);
    function approvedBySeller() external view returns (bool);
}