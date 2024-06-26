## Stablecoins

**Stablecoins are cryptocurrencies that are designed to have stable price.**

### Libraries used
1. **forge install openzeppelin/openzeppelin-contracts --no-commit**
2. **forge install smartcontractkit/chainlink-brownie-contracts --no-commit**

## Features
1. Relative Stability: Anchored or Pegged -> $1.00
    1. Chainlink price feed
    2. Set a function to exchange ETH and BTC ->$$$
2. Stability Mechanism (Minting): Algorithmic (Decentralized)
    1. People can only mint stablecoin with enough collateral
3. Collateral: Exogenous (Crypto)
    1. wETH
    2. wBTC


## Liquidate Feature note
Liquidator can cover debt of a user by burning their DSC debt, and get all their collateral in return.

## Formal Verification
Act of proving or disproving a given property using a mathematical model.
    - Stateful fuzzing ->  An advanced testing technique used to identify bugs in a system
    that maintain state across interactions, such as network protocols or interactive applications.
    Unlike traditional fuzzing, which treats system as a blackbox and throw random numbers at it,
    stateful fuzzing understands concept of different states and attempts to transition the system
    through different states in a meaningful way. 

    In other words, the ending state of the previous state is the starting state of next test as 
    opposed to stateless fuzzing. So any changes to state variables are preserved/committed
    for next test!

    In foundry, stateful fuzzing == Invariant fuzzing

1. What are invariants/properties? That way, we can write stateful and stateless tests.




| Functions                                              | 
| :---                                                   | 


> [**depositCollateral** (tokenCollateralAddress, amountCollateral)](#function-depositcollateral)   

> **mintDsc** ( dscAmountToMint)                                                   

> **depositCollateralAndMintDsc** (tokenCollateralAddress, amountCollateral, dscAmountToMint)  

> **redeemCollateral** (tokenCollateralAddress,  amountCollateral)      

> **redeemCollateralForDsc** (tokenCollateralAddress,  amountCollateral,  dscAmountToBurn)      






###### Function depositCollateral
---
**depositCollateral** (*address* tokenCollateralAddress, *uint256* amountCollateral)
- Deposits given amountCollateral of a tokenCollateralAddress to msg.sender's account.                                            |

