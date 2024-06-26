// SPDX-License-Identifier: MIT

// What are our invariants?

// 1. Total supply of DSC should always be less than total collateral
// 2. Getter/View functions should never fail

pragma solidity ^0.8.18;

import {Handler} from "./Handler.t.sol";
import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

/**
 * @dev Add properties to this test function which the system should always hold!
 * Test contract functions inside handler. This invariance test will trigger
 * those functions and checks if the property holds true when they're triggered!
 *
 * For example: For this case, we want DSCEngine to have collateral > mintedDSC
 * at any point in time. So we add that here, and run fuzzers against it inside
 * handler.
 */
contract InvariantTest is StdInvariant, Test {
    Handler public handler;
    DSCEngine public engine;
    HelperConfig public config;
    DecentralizedStableCoin public dsc;

    address public weth;
    address public wbtc;
    address public alice = makeAddr("alice");

    function setUp() public {
        DeployDSC dscDeploy = new DeployDSC();
        (dsc, engine, config) = dscDeploy.run();
        (,, weth, wbtc,) = config.activeNetwork();
        deal(alice, 10 ether);

        // Hander starts
        handler = new Handler(engine, dsc);
        targetContract(address(handler));
        // Handler ends

        // Tells foundry to go wild on engine! targetContract comes from StdInvariant
        // targetContract(address(engine));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // Get value of all collateral in protocol
        // Compare that against total DSC minted
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalBtcDeposited);

        assert(wethValue + wbtcValue >= totalSupply);
    }

    /**
     * @dev Put all getters in there. It tests for all getters to pass.
     * It's a layup function of invariant. Don't change its name.
     */
    function invariant_gettersShouldNeverRevert() public view {
        engine.getCollateralTokens();
    }
}
