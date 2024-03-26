// SPDX-License-Identifier: MIT

// Handler narrows function calls
// For example, we don't want redeemCollateral to be called by invariant before anything is deposited.
// Otherwise, it would be wasting time and resources. Handler gives things order. 


pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";


contract Handler is Test {

    DSCEngine engine;
    DecentralizedStableCoin dsc;

    address weth;
    address wbtc;

    uint256 constant MAX_DEPOSIT_SIZE = type(uint96).max; // max uint96 value

    address[] public usersWithCollateralDeposited;

    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        engine = _engine;
        dsc = _dsc;
        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = collateralTokens[0];
        wbtc = collateralTokens[1];
    }

    function mintDsc(uint256 amountToMint, uint256 senderSeed) public {
        
        if (usersWithCollateralDeposited.length == 0) return;
        
        /** 
         * @dev The line below ensures that only those who deposited collateral can mintDsc.
        */
        address user = usersWithCollateralDeposited[senderSeed % usersWithCollateralDeposited.length];
        vm.startPrank(user);

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInFormation(user);
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        if (maxDscToMint < 0) return; 
        amountToMint = bound(amountToMint, 0, uint256(maxDscToMint));
        if (amountToMint == 0) return;

        engine.mintDsc(amountToMint);
        vm.stopPrank();
    }

    /**
     * @dev Instead of passing it random addresses, we'd want to pass only valid collateral address
     * in order to check protocolMustHaveMoreValueThanTotalSupply property.
     */
    // function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        address collateral = _getCollateralFromSeed(collateralSeed);

        /**
         * @dev bound bounds a fuzz value between lowerbound and upperbound. 
         */
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        ERC20Mock(collateral).mint(msg.sender, amountCollateral);
        ERC20Mock(collateral).approve(address(engine), amountCollateral);

        engine.depositCollateral(collateral, amountCollateral);
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        address collateralToken = _getCollateralFromSeed(collateralSeed);
        vm.startPrank(msg.sender);
        uint256 maxCollateralToRedeem = engine.getTotalCollateralValueOfUser(msg.sender, collateralToken);
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) return;

        engine.redeemCollateral(collateralToken, amountCollateral);

        vm.stopPrank();
    }

    ////////////////////////
    /// Helper functions ///
    ////////////////////////

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (address){
        if (collateralSeed % 2 == 0) {
            return weth;
        }

        return wbtc;
    }

}

