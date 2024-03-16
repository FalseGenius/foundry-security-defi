// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployDSC is Script {

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine) {
        HelperConfig config = new HelperConfig();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            config.activeNetwork();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        
        vm.startBroadcast();
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedAddresses,address(dsc));
        vm.stopBroadcast();


        /**
         * @dev Only the engine can make use of dsc since the core logic is there
         */
        dsc.transferOwnership(address(engine));

        return (dsc, engine);
    }
}
