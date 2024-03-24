## Stablecoins

**Stablecoins are cryptocurrencies that are designed to have stable price.**

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
