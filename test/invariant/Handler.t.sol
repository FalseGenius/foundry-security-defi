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

    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        engine = _engine;
        dsc = _dsc;
        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = collateralTokens[0];
        wbtc = collateralTokens[1];
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

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (address){
        if (collateralSeed % 2 == 0) {
            return weth;
        }

        return wbtc;
    }

}

