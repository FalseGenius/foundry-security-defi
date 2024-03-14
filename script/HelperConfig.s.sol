// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetwork;

    constructor() {
        if (block.chainid == 11155111) activeNetwork = getSepoliaConfig();
        else activeNetwork = getOrCreateAnvilConfig();
    }

    function getSepoliaConfig() public returns (NetworkConfig memory) {}
    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {}
}