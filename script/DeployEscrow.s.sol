// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/Escrow.sol";

contract DeployEscrow is Script {
    function run() external returns (Escrow) {
        address buyer = vm.envAddress("BUYER");
        address seller = vm.envAddress("SELLER");
        address arbiter = vm.envAddress("ARBITER");
        uint256 amount = vm.envUint("AMOUNT");

        vm.startBroadcast();
        Escrow escrow = new Escrow(buyer, seller, arbiter, amount);
        vm.stopBroadcast();

        return escrow;
    }
}
