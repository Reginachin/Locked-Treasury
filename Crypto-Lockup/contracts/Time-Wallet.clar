;; TimeSafe - Decentralized Asset Time-Lock Protocol
;; A secure solution for time-locking STX and fungible tokens with advanced beneficiary management
;; Allows users to create time-locked vaults with configurable unlock periods and designated beneficiaries

(define-data-var contract-administrator principal tx-sender)

;; Time-related validation constants
(define-constant MIN-LOCKUP-DURATION u144) ;; Minimum 1 day (144 blocks)
(define-constant MAX-LOCKUP-DURATION u52560) ;; Maximum 1 year
(define-constant MIN-SAFETY-PERIOD u144) ;; Minimum 1 day grace period
(define-constant DEFAULT-SAFETY-PERIOD u4320) ;; Default 30 days grace period

;; Beneficiary status codes
(define-constant BENEFICIARY-STATUS-ACTIVE u1)
(define-constant BENEFICIARY-STATUS-PENDING u2)
(define-constant BENEFICIARY-STATUS-INACTIVE u0)

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-VAULT-NOT-FOUND (err u101))
(define-constant ERR-VAULT-ALREADY-EXISTS (err u102))
(define-constant ERR-ASSETS-STILL-LOCKED (err u103))
(define-constant ERR-SAFETY-PERIOD-EXPIRED (err u104))
(define-constant ERR-INSUFFICIENT-BALANCE (err u105))
(define-constant ERR-INVALID-LOCKUP-DURATION (err u106))
(define-constant ERR-EXTENSION-PERIOD-TOO-SHORT (err u107))
(define-constant ERR-INVALID-BENEFICIARY-ADDRESS (err u108))
(define-constant ERR-NO-BENEFICIARY-ASSIGNED (err u109))
(define-constant ERR-BENEFICIARY-NOT-AUTHORIZED (err u110))

;; Vault data structure
(define-map time-locked-vaults
    { vault-owner: principal }
    {
        locked-amount: uint,
        unlock-block-height: uint,
        lockup-duration-blocks: uint,
        designated-beneficiary: (optional principal),
        beneficiary-access-status: uint,
        inactivity-grace-period: uint,
        last-activity-timestamp: uint,
        asset-type: (string-ascii 32)
    }
)

;; Read-only functions

(define-read-only (get-vault-information (vault-owner principal))
    (map-get? time-locked-vaults { vault-owner: vault-owner })
)

(define-read-only (check-if-unlocked (vault-owner principal))
    (let (
        (vault-data (unwrap! (get-vault-information vault-owner) false))
        (current-block-height block-height)
    )
    (>= current-block-height (get unlock-block-height vault-data)))
)

(define-read-only (calculate-remaining-lock-time (vault-owner principal))
    (let (
        (vault-data (unwrap! (get-vault-information vault-owner) u0))
        (current-block-height block-height)
    )
    (if (>= current-block-height (get unlock-block-height vault-data))
        u0
        (- (get unlock-block-height vault-data) current-block-height)))
)

(define-read-only (verify-beneficiary-claim-eligibility (vault-owner principal) (beneficiary-address principal))
    (let (
        (vault-data (unwrap! (get-vault-information vault-owner) false))
        (current-block-height block-height)
        (safety-period-end (+ (get unlock-block-height vault-data) (get inactivity-grace-period vault-data)))
        (owner-inactivity-duration (- current-block-height (get last-activity-timestamp vault-data)))
    )
    (and
        (is-eq (some beneficiary-address) (get designated-beneficiary vault-data))
        (is-eq (get beneficiary-access-status vault-data) BENEFICIARY-STATUS-ACTIVE)
        (or 
            (>= current-block-height safety-period-end)
            (>= owner-inactivity-duration (get inactivity-grace-period vault-data))
        )
    ))
)

;; Public functions

(define-public (create-new-vault (lockup-duration uint) (beneficiary-address (optional principal)) (safety-period uint))
    (let (
        (unlock-block-height (+ block-height lockup-duration))
        (effective-safety-period (if (< safety-period MIN-SAFETY-PERIOD) 
                                DEFAULT-SAFETY-PERIOD 
                                safety-period))
    )
    (asserts! (is-none (get-vault-information tx-sender)) ERR-VAULT-ALREADY-EXISTS)
    (asserts! (and (>= lockup-duration MIN-LOCKUP-DURATION) (<= lockup-duration MAX-LOCKUP-DURATION)) ERR-INVALID-LOCKUP-DURATION)
    
    (map-set time-locked-vaults
        { vault-owner: tx-sender }
        {
            locked-amount: u0,
            unlock-block-height: unlock-block-height,
            lockup-duration-blocks: lockup-duration,
            designated-beneficiary: beneficiary-address,
            beneficiary-access-status: (if (is-some beneficiary-address) BENEFICIARY-STATUS-ACTIVE BENEFICIARY-STATUS-INACTIVE),
            inactivity-grace-period: effective-safety-period,
            last-activity-timestamp: block-height,
            asset-type: "STX"
        }
    )
    (ok true))
)

(define-public (extend-lockup-period (additional-blocks uint))
    (let (
        (vault-data (unwrap! (get-vault-information tx-sender) ERR-VAULT-NOT-FOUND))
        (current-block-height block-height)
        (new-unlock-height (+ (get unlock-block-height vault-data) additional-blocks))
        (new-total-duration (+ (get lockup-duration-blocks vault-data) additional-blocks))
    )
    (asserts! (>= additional-blocks MIN-LOCKUP-DURATION) ERR-EXTENSION-PERIOD-TOO-SHORT)
    (asserts! (<= new-total-duration MAX-LOCKUP-DURATION) ERR-INVALID-LOCKUP-DURATION)
    
    (map-set time-locked-vaults
        { vault-owner: tx-sender }
        (merge vault-data {
            unlock-block-height: new-unlock-height,
            lockup-duration-blocks: new-total-duration,
            last-activity-timestamp: current-block-height
        })
    )
    (ok true))
)

(define-public (modify-beneficiary (updated-beneficiary (optional principal)))
    (let (
        (vault-data (unwrap! (get-vault-information tx-sender) ERR-VAULT-NOT-FOUND))
    )
    (map-set time-locked-vaults
        { vault-owner: tx-sender }
        (merge vault-data {
            designated-beneficiary: updated-beneficiary,
            beneficiary-access-status: (if (is-some updated-beneficiary) BENEFICIARY-STATUS-ACTIVE BENEFICIARY-STATUS-INACTIVE),
            last-activity-timestamp: block-height
        })
    )
    (ok true))
)

(define-public (deposit-stx-funds (deposit-amount uint))
    (let (
        (vault-data (unwrap! (get-vault-information tx-sender) ERR-VAULT-NOT-FOUND))
    )
    (try! (stx-transfer? deposit-amount tx-sender (as-contract tx-sender)))
    (map-set time-locked-vaults
        { vault-owner: tx-sender }
        (merge vault-data {
            locked-amount: (+ (get locked-amount vault-data) deposit-amount),
            last-activity-timestamp: block-height
        })
    )
    (ok true))
)

(define-public (withdraw-stx-funds (withdrawal-amount uint))
    (let (
        (vault-data (unwrap! (get-vault-information tx-sender) ERR-VAULT-NOT-FOUND))
        (current-block-height block-height)
    )
    (asserts! (>= current-block-height (get unlock-block-height vault-data)) ERR-ASSETS-STILL-LOCKED)
    (asserts! (<= withdrawal-amount (get locked-amount vault-data)) ERR-INSUFFICIENT-BALANCE)
    
    (try! (as-contract (stx-transfer? withdrawal-amount (as-contract tx-sender) tx-sender)))
    (map-set time-locked-vaults
        { vault-owner: tx-sender }
        (merge vault-data {
            locked-amount: (- (get locked-amount vault-data) withdrawal-amount),
            last-activity-timestamp: current-block-height
        })
    )
    (ok true))
)

(define-public (execute-beneficiary-claim (vault-owner principal))
    (let (
        (vault-data (unwrap! (get-vault-information vault-owner) ERR-VAULT-NOT-FOUND))
        (current-block-height block-height)
        (safety-period-end (+ (get unlock-block-height vault-data) (get inactivity-grace-period vault-data)))
        (owner-inactivity-duration (- current-block-height (get last-activity-timestamp vault-data)))
    )
    ;; Verify beneficiary status and conditions
    (asserts! (is-some (get designated-beneficiary vault-data)) ERR-NO-BENEFICIARY-ASSIGNED)
    (asserts! (is-eq (some tx-sender) (get designated-beneficiary vault-data)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get beneficiary-access-status vault-data) BENEFICIARY-STATUS-ACTIVE) ERR-BENEFICIARY-NOT-AUTHORIZED)
    (asserts! (or 
        (>= current-block-height safety-period-end)
        (>= owner-inactivity-duration (get inactivity-grace-period vault-data))
    ) ERR-ASSETS-STILL-LOCKED)
    
    ;; Transfer funds and close vault
    (try! (as-contract (stx-transfer? (get locked-amount vault-data) (as-contract tx-sender) tx-sender)))
    (map-delete time-locked-vaults { vault-owner: vault-owner })
    (ok true))
)

(define-public (register-activity)
    (let (
        (vault-data (unwrap! (get-vault-information tx-sender) ERR-VAULT-NOT-FOUND))
    )
    (map-set time-locked-vaults
        { vault-owner: tx-sender }
        (merge vault-data { last-activity-timestamp: block-height })
    )
    (ok true))
)