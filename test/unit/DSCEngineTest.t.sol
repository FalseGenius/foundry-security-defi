// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DSCEngineTest is Test {
    address weth;
    address wethUsdPriceFeed;
    address public alice = makeAddr("alice");
    address public liquidator = makeAddr("liquidator");

    uint256 amountToMint = 100 ether;
    uint256 collateralToCover = 20 ether;
    uint256 constant AMOUNT_COLLATERAL = 10 ether;
    uint256 constant STARTING_ERC20_BALANCE = 10 ether;

    DSCEngine public engine;
    DeployDSC public deployer;
    HelperConfig public config;
    DecentralizedStableCoin public dsc;

    event CollateralRedeemed(
        address indexed redeemed_from, address indexed redeemed_to, address indexed token, uint256 amountCollateral
    );

    modifier depositCollateral() {
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier depositCollateralAndMintDsc() {
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        engine.mintDsc(amountToMint);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (wethUsdPriceFeed,, weth,,) = config.activeNetwork();

        // The lines below achieve the same. They both deal alice 10 ether worth weth.
        ERC20Mock(weth).mint(alice, STARTING_ERC20_BALANCE);
        ERC20Mock(weth).mint(liquidator, collateralToCover);
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

    ////////////////////////////////
    /// Redeem Collateral Tests ///
    ////////////////////////////////

    function testRevertsRedeemCollateralValueIsZero() public depositCollateral {
        vm.startPrank(alice);
        
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositCollateral {
        vm.startPrank(alice);
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        uint256 collateralAfterRedeem = ERC20Mock(weth).balanceOf(alice);
        assertEq(collateralAfterRedeem, AMOUNT_COLLATERAL);
        
        vm.stopPrank();
    }

    function testEmitsEventWhenCollateralIsRedeemed() public depositCollateral {
        vm.expectEmit(true, true, true, true, address(engine));
        emit CollateralRedeemed(alice, alice, weth, AMOUNT_COLLATERAL);
        vm.startPrank(alice);
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }


    //////////////////////
    /// Mint DSC Tests ///
    //////////////////////

    function testRevertsIfAmountToMintIsZero() public depositCollateral {
        vm.prank(alice);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.mintDsc(0);
    }

    function testCanMintDsc() public depositCollateral {
        
        // uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        // return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;

        // Collateral Deposited = 10e18;
        // AmountToMint = 100e18;
        // collateralAdjustedForThreshold = 2000 * amount(10) * 0.5
        // healthFactor = collateralAdjustedForThreshold (10000) / 100 = 100

        vm.startPrank(alice);
        engine.mintDsc(amountToMint);
        uint256 amountMinted = engine.getTotalDscMintedByAUser(alice);
        vm.stopPrank();

        assertEq(amountMinted, amountToMint);
    }

    function testRevertsIfMintAmountBreaksHealthFactor() public depositCollateral {

        (, int256 price,,,) = MockV3Aggregator(wethUsdPriceFeed).latestRoundData();

        // uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        // return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;

        // ADDITIONAL_FEED_PRECISION = 1e10
        // PRECISION = 1e18
        // price = 2000e8
        // AMOUNT_COLLATERAL = 10e18

        // Collateral Deposited = 10e18;
        // AmountToMint = 20000e18 
        // collateralAdjustedForThreshold = 2000 * amount(10) * 0.5
        // healthFactor = collateralAdjustedForThreshold (10000) / 20000 = 0.5 which is less than 1


        /**
         * @dev We are doing this to make AMOUNT_COLLATERAL large, for testing purposes.
         */
        amountToMint = (AMOUNT_COLLATERAL * (uint256(price) * engine.getAdditionalFeedPrecision())) / engine.getPrecision();
        console.log(amountToMint);
        vm.startPrank(alice);
        uint256 usdValue = engine.getUsdValue(weth, AMOUNT_COLLATERAL);
        uint256 userHealthFactor = engine.calculateHealthFactor(usdValue, amountToMint);
        // uint256 userHealthFactor = engine.getHealthFactor(alice);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__HealthFactorBelowMinimum.selector, userHealthFactor));
        engine.mintDsc(amountToMint);

        vm.stopPrank(); 
    }

    //////////////////////
    /// Burn DSC Tests ///
    //////////////////////

    function testRevertsIfAmountToBurnIsZero() public depositCollateral {
        vm.startPrank(alice);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.burnDsc(0);

        vm.stopPrank();
    }

    function testCanBurnDsc() public depositCollateral {
        vm.startPrank(alice);
        engine.mintDsc(amountToMint);
        
        /**
         * @dev When minting dsc, we don't need to dsc to approve engine since nothing's being transfered
         * from dsc to engine. For burning dsc, it transfers the amoutToMint(which is amountToBurn) to
         * the engine and then, it destroys it. Basically, ownership of the amountToMint dsc is tranferred to 
         * engine from user and it requires approval.
         */
        dsc.approve(address(engine), amountToMint);
        engine.burnDsc(amountToMint);
        uint256 balanceLeft = dsc.balanceOf(alice);
        vm.stopPrank();

        assertEq(balanceLeft, 0);
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(alice);
        vm.expectRevert();
        engine.burnDsc(1);

    }

    //////////////////////
    /// Liquidate Tests //
    //////////////////////

    function testRevertsIfDebtToCoverIsZero() public {
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.liquidate(weth, alice,0);
        
    }

    function testRevertsIfHealthFactorIsAboveMinimum() public depositCollateralAndMintDsc {
        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(engine), collateralToCover);
        engine.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint);

        dsc.approve(address(engine), amountToMint);

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(weth, alice, amountToMint);
        vm.stopPrank();
    }

    modifier liquidateUser() {
        (, int256 price,,,) = MockV3Aggregator(wethUsdPriceFeed).latestRoundData();
        
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        dsc.approve(address(engine), amountToMint);
        engine.mintDsc(amountToMint);
        vm.stopPrank();

        int256 newEthUsdPrice = 18e8;
        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(newEthUsdPrice);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(engine), collateralToCover);
        dsc.approve(address(engine), amountToMint);
        engine.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint);

        engine.liquidate(weth, alice, amountToMint);
        vm.stopPrank();
        _;
    }

    function testLiquidatorTakesUsersDebt() public {
        (uint256 totalDscMinted, ) = engine.getAccountInFormation(liquidator);
        assertEq(totalDscMinted, amountToMint);

    }

    function testUserHasNoMoreDebt() public liquidateUser {
        (uint256 totalDscMinted, ) = engine.getAccountInFormation(alice);
        assertEq(totalDscMinted, 0);
    }
}
