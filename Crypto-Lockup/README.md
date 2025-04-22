# TimeSafe: Decentralized Asset Time-Lock Protocol

## Overview

TimeSafe is a secure Clarity smart contract for the Stacks blockchain that enables users to create time-locked vaults for STX and fungible tokens. The protocol implements advanced beneficiary management features, configurable lock periods, and safety mechanisms to ensure asset security.

## Key Features

- **Time-Locked Vaults**: Lock your STX assets for a specified period (between 1 day and 1 year)
- **Beneficiary Management**: Designate backup beneficiaries who can claim assets after inactivity periods
- **Configurable Safety Periods**: Set grace periods to protect against accidental loss of access
- **Extendable Lock Periods**: Increase your vault's lock duration if needed
- **Activity Registration**: Prove continued control over your assets
- **Secure Withdrawal**: Access your assets when the lock period expires

## Functions

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-vault-information` | Returns all data about a specified vault |
| `check-if-unlocked` | Checks if a vault's lock period has expired |
| `calculate-remaining-lock-time` | Returns the blocks remaining until the vault unlocks |
| `verify-beneficiary-claim-eligibility` | Checks if a beneficiary can claim assets from a vault |

### Public Functions

| Function | Description |
|----------|-------------|
| `create-new-vault` | Creates a new time-locked vault with specified parameters |
| `extend-lockup-period` | Extends the lock period of an existing vault |
| `modify-beneficiary` | Updates or removes the designated beneficiary of a vault |
| `deposit-stx-funds` | Adds STX to a vault |
| `withdraw-stx-funds` | Withdraws STX from an unlocked vault |
| `execute-beneficiary-claim` | Allows a beneficiary to claim assets after owner inactivity |
| `register-activity` | Updates the last activity timestamp for a vault |

## Usage Examples

### Creating a Vault

```clarity
;; Create a vault with a 30-day lock period (4320 blocks), no beneficiary
(contract-call? .timesafe create-new-vault u4320 none u4320)

;; Create a vault with a 90-day lock period (12960 blocks) and a beneficiary
(contract-call? .timesafe create-new-vault u12960 (some 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) u4320)
```

### Depositing and Withdrawing Funds

```clarity
;; Deposit 1000 STX into your vault
(contract-call? .timesafe deposit-stx-funds u1000)

;; Withdraw 500 STX from your vault (only works after unlock time)
(contract-call? .timesafe withdraw-stx-funds u500)
```

### Managing Beneficiaries

```clarity
;; Update your vault's beneficiary
(contract-call? .timesafe modify-beneficiary (some 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG))

;; Remove a beneficiary from your vault
(contract-call? .timesafe modify-beneficiary none)
```

### Beneficiary Claims

```clarity
;; As a beneficiary, claim assets from an inactive vault
(contract-call? .timesafe execute-beneficiary-claim 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## Security Parameters

- **Minimum Lock Period**: 1 day (144 blocks)
- **Maximum Lock Period**: 1 year (52,560 blocks)
- **Minimum Safety Period**: 1 day (144 blocks)
- **Default Safety Period**: 30 days (4,320 blocks)

## Error Codes

| Code | Description |
|------|-------------|
| 100 | Unauthorized access |
| 101 | Vault not found |
| 102 | Vault already exists |
| 103 | Assets still locked |
| 104 | Safety period expired |
| 105 | Insufficient balance |
| 106 | Invalid lockup duration |
| 107 | Extension period too short |
| 108 | Invalid beneficiary address |
| 109 | No beneficiary assigned |
| 110 | Beneficiary not authorized |

## Use Cases

- **Long-term Savings**: Lock assets to prevent impulsive spending
- **Inheritance Planning**: Ensure assets can be accessed by designated beneficiaries
- **Digital Estate Planning**: Create backup access mechanisms for your assets
- **Dead Man's Switch**: Automate asset transfers after periods of inactivity
- **Secure Asset Custody**: Add time-based security to your digital assets