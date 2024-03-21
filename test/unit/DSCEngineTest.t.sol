// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DSCEngineTest is Test {

    address weth;
    address wethUsdPriceFeed;
    address public alice = makeAddr("alice");
    
    DSCEngine public engine;
    DeployDSC public deployer;
    HelperConfig public config;
    DecentralizedStableCoin public dsc;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (wethUsdPriceFeed,, weth,,) = config.activeNetwork();
        deal(alice, 1 ether);
    }


    ///////////////////
    /// Price Tests ///
    ///////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        // 15e8 * 2000/ETH = 30,000e18
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }
}