// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DSCEngineTest is Test {
    address weth;
    address wethUsdPriceFeed;
    address public alice = makeAddr("alice");

    uint256 constant AMOUNT_COLLATERAL = 10 ether;
    uint256 constant STARTING_ERC20_BALANCE = 10 ether;

    DSCEngine public engine;
    DeployDSC public deployer;
    HelperConfig public config;
    DecentralizedStableCoin public dsc;

    modifier depositCollateral() {
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (wethUsdPriceFeed,, weth,,) = config.activeNetwork();

        // The lines below achieve the same. They both deal alice 10 ether worth weth.
        ERC20Mock(weth).mint(alice, STARTING_ERC20_BALANCE);
        // deal(weth, alice, STARTING_ERC20_BALANCE);
    }

    /////////////////////////
    /// Constructor Tests ///
    /////////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthsDoNotMatch() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(wethUsdPriceFeed);
        priceFeedAddresses.push(wethUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
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

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        // $ 2000/ETH, we have $ 100 amount so token returned = 100/2000 = 0.05 ETH
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(actualWeth, expectedWeth);
    }

    ////////////////////////////////
    /// Deposit Collateral Tests ///
    ////////////////////////////////

    function testRevertsIfCollateralValueIsZero() public {
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        // COde this
        ERC20Mock erc = new ERC20Mock("erc", "ERC", alice, STARTING_ERC20_BALANCE);
        vm.prank(alice);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(erc), STARTING_ERC20_BALANCE);
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInFormation(alice);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedCollateralValueAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(expectedCollateralValueAmount, AMOUNT_COLLATERAL);
    }

    // Write tests to raise DSCEngine coverage to 85+
}
