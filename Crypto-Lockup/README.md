# TimeSafe: Decentralized Asset Time-Lock Protocol

## Overview

TimeSafe is a secure Clarity smart contract for the Stacks blockchain that enables users to create time-locked vaults for STX and fungible tokens. The protocol implements advanced beneficiary management features, configurable lock periods, and safety mechanisms to ensure asset security.

## Key Features

- **Time-Locked Vaults**: Lock your STX and fungible token assets for a specified period (between 1 day and 1 year)
- **Multi-Asset Support**: Lock both STX and fungible tokens in specialized vaults
- **Beneficiary Management**: Designate backup beneficiaries who can claim assets after inactivity periods
- **Configurable Safety Periods**: Set grace periods to protect against accidental loss of access
- **Extendable Lock Periods**: Increase your vault's lock duration if needed
- **Activity Registration**: Prove continued control over your assets
- **Secure Withdrawal**: Access your assets when the lock period expires
- **Emergency Withdrawal**: Access locked funds before the unlock time with a penalty fee
- **Beneficiary Confirmation**: Two-step process for adding beneficiaries that requires approval

## Functions

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-vault-information` | Returns all data about a specified vault |
| `check-if-unlocked` | Checks if a vault's lock period has expired |
| `calculate-remaining-lock-time` | Returns the blocks remaining until the vault unlocks |
| `verify-beneficiary-claim-eligibility` | Checks if a beneficiary can claim assets from a vault |
| `calculate-emergency-withdrawal-fee` | Calculates the penalty fee for emergency withdrawals |
| `get-event` | Retrieves logged events by ID |
| `get-current-administrator` | Returns the current contract administrator |

### Public Functions

| Function | Description |
|----------|-------------|
| `create-new-vault` | Creates a new time-locked vault with specified parameters |
| `extend-lockup-period` | Extends the lock period of an existing vault |
| `modify-beneficiary` | Updates or removes the designated beneficiary of a vault |
| `confirm-beneficiary-status` | Allows a beneficiary to accept their designation |
| `deposit-stx-funds` | Adds STX to a vault |
| `deposit-ft-funds` | Adds fungible tokens to a vault |
| `withdraw-stx-funds` | Withdraws STX from an unlocked vault |
| `withdraw-ft-funds` | Withdraws fungible tokens from an unlocked vault |
| `emergency-withdrawal` | Withdraws funds before unlock time with a 10% penalty fee |
| `execute-beneficiary-claim` | Allows a beneficiary to claim assets after owner inactivity |
| `close-vault` | Removes an empty vault after the lock period expires |
| `register-activity` | Updates the last activity timestamp for a vault |
| `set-administrator` | Updates the contract administrator (admin only) |

## Usage Examples

### Creating a Vault

```clarity
;; Create an STX vault with a 30-day lock period (4320 blocks), no beneficiary
(contract-call? .timesafe create-new-vault u4320 none u4320 "STX" none none)

;; Create an STX vault with a 90-day lock period (12960 blocks) and a beneficiary
(contract-call? .timesafe create-new-vault u12960 (some 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) u4320 "STX" none none)

;; Create a fungible token vault with a 60-day lock period (8640 blocks)
(contract-call? .timesafe create-new-vault u8640 none u4320 "FT" (some 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.my-token) (some "TOKEN-A"))
```

### Depositing and Withdrawing Funds

```clarity
;; Deposit 1000 STX into your vault
(contract-call? .timesafe deposit-stx-funds u1000)

;; Deposit 500 fungible tokens into your vault
(contract-call? .timesafe deposit-ft-funds u500)

;; Withdraw 500 STX from your vault (only works after unlock time)
(contract-call? .timesafe withdraw-stx-funds u500)

;; Withdraw 200 fungible tokens from your vault (only works after unlock time)
(contract-call? .timesafe withdraw-ft-funds u200)

;; Emergency withdrawal of 300 STX (works anytime, but incurs a 10% fee)
(contract-call? .timesafe emergency-withdrawal u300)
```

### Managing Beneficiaries

```clarity
;; Update your vault's beneficiary
(contract-call? .timesafe modify-beneficiary (some 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG))

;; As the beneficiary, confirm your status
(contract-call? .timesafe confirm-beneficiary-status 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Remove a beneficiary from your vault
(contract-call? .timesafe modify-beneficiary none)
```

### Beneficiary Claims and Vault Management

```clarity
;; As a beneficiary, claim assets from an inactive vault
(contract-call? .timesafe execute-beneficiary-claim 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Extend your vault's lock period by 30 more days
(contract-call? .timesafe extend-lockup-period u4320)

;; Register activity to maintain control of your vault
(contract-call? .timesafe register-activity)

;; Close an empty vault after the lock period
(contract-call? .timesafe close-vault)
```

## Security Parameters

- **Minimum Lock Period**: 1 day (144 blocks)
- **Maximum Lock Period**: 1 year (52,560 blocks)
- **Minimum Safety Period**: 1 day (144 blocks)
- **Default Safety Period**: 30 days (4,320 blocks)
- **Emergency Withdrawal Fee**: 10% (1000 basis points)

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
| 111 | Zero amount specified |
| 112 | Unsupported token |
| 113 | Only admin allowed |
| 114 | Invalid admin address |

## Use Cases

- **Long-term Savings**: Lock assets to prevent impulsive spending
- **Inheritance Planning**: Ensure assets can be accessed by designated beneficiaries
- **Digital Estate Planning**: Create backup access mechanisms for your assets
- **Dead Man's Switch**: Automate asset transfers after periods of inactivity
- **Secure Asset Custody**: Add time-based security to your digital assets
- **Token Vesting**: Create simple vesting schedules for token distributions
- **Commitment Devices**: Lock funds to commit to future goals