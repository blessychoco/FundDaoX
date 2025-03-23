# FundDaoX: Decentralized Funding Platform

FundDaoX is an on-chain decentralized funding platform that allows innovators to raise funds for their ventures in a transparent, goal-oriented manner using Stacks blockchain technology.

## Overview

FundDaoX leverages smart contracts to create a trustless environment where founders can establish funding ventures with clearly defined goals. Backers can contribute STX tokens to ventures they believe in, with funds released only when pre-defined goals are completed and verified.

## Key Features

- **Goal-based Funding**: Ventures are broken down into specific goals with allocated funds
- **Milestone Verification**: Founders must complete and verify each goal to access funds
- **Automatic Refunds**: If a venture doesn't meet its funding goal by the deadline, backers can withdraw their contributions
- **Transparent Governance**: All funding activities are recorded on-chain for complete transparency
- **User-controlled Funds**: Backers maintain control over their contributions until ventures are successfully funded

## Smart Contract Structure

The FundDaoX platform is built on a Clarity smart contract with these core components:

- **Ventures**: Contains all venture information including funding goals, collected amounts, and completion status
- **Goals**: Each venture has up to 5 goals, each with funding allocations that must be completed sequentially
- **Backers**: Tracks all contributions and withdrawal status for each backer

## How It Works

1. **Create a Venture**: A founder creates a venture by specifying a name, summary, funding goal, end date, and a list of goals.

2. **Back a Venture**: Backers can contribute STX tokens to ventures they want to support before the end date.

3. **Complete Goals**: Once the funding goal is reached, the founder must complete each goal and mark it as completed.

4. **Finalize Venture**: After all goals are completed, the founder can finalize the venture, making the funds available.

5. **Withdrawal System**: If a venture fails to reach its funding goal by the end date, backers can withdraw their contributions.

## Usage Examples

### Creating a Venture

```clarity
(contract-call? .funddaox create-venture 
  "Green Energy Startup" 
  "Developing affordable solar panels for residential use" 
  u10000000 
  u100000 
  (list 
    {summary: "Research and Prototyping", funds: u2000000}
    {summary: "Manufacturing Setup", funds: u5000000}
    {summary: "Market Testing", funds: u3000000}
  )
)
```

### Backing a Venture

```clarity
(contract-call? .funddaox back-venture u1 u500000)
```

### Completing a Goal

```clarity
(contract-call? .funddaox complete-goal u1 u0)  ;; Complete the first goal
```

## Error Handling

The contract includes robust error handling to ensure secure operations:

- ERR-NOT-AUTHORIZED (u100): User not authorized for this action
- ERR-FUNDS-SHORTAGE (u101): Insufficient funds for operation
- ERR-VENTURE-NOT-FOUND (u102): Requested venture does not exist
- ERR-FUNDING-CLOSED (u103): Venture is no longer accepting contributions
- And more...

## Security Considerations

- The smart contract uses authorization checks to ensure only the appropriate users can perform specific actions
- All functions include input validation to prevent invalid operations
- The contract follows best practices for Clarity development
