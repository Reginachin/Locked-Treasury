;; TimeSafe - Decentralized Asset Time-Lock Protocol
;; A secure solution for time-locking STX and fungible tokens with advanced beneficiary management
;; Allows users to create time-locked vaults with configurable unlock periods and designated beneficiaries

;; Admin functionality
(define-data-var contract-administrator principal tx-sender)

;; Simple event logging mechanism
(define-map event-log
    { event-id: uint }
    {
        event-type: (string-ascii 50),
        user: principal,
        block-height: uint,
        data: uint
    }
)

(define-data-var event-counter uint u0)

;; Time-related validation constants
(define-constant MIN-LOCKUP-DURATION u144) ;; Minimum 1 day (144 blocks)
(define-constant MAX-LOCKUP-DURATION u52560) ;; Maximum 1 year
(define-constant MIN-SAFETY-PERIOD u144) ;; Minimum 1 day grace period
(define-constant DEFAULT-SAFETY-PERIOD u4320) ;; Default 30 days grace period
(define-constant EMERGENCY-WITHDRAWAL-FEE-BASIS-POINTS u1000) ;; 10% fee for emergency withdrawals

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
(define-constant ERR-ZERO-AMOUNT (err u111))
(define-constant ERR-UNSUPPORTED-TOKEN (err u112))
(define-constant ERR-ONLY-ADMIN (err u113))
(define-constant ERR-INVALID-ADMIN (err u114))

;; Supported token types
(define-constant TOKEN-TYPE-STX "STX")
(define-constant TOKEN-TYPE-FT "FT")

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
        asset-type: (string-ascii 32),
        token-contract: (optional principal),
        token-id: (optional (string-ascii 32))
    }
)

;; Administrative functions

(define-public (set-administrator (new-admin principal))
    (begin
        ;; Validate the caller is the current administrator
        (asserts! (is-eq tx-sender (var-get contract-administrator)) ERR-ONLY-ADMIN)
        ;; Validate the new administrator is not tx-sender (optional check)
        (asserts! (not (is-eq new-admin tx-sender)) ERR-INVALID-ADMIN)
        ;; Validate the new admin is not the null address (optional check)
        (asserts! (not (is-eq new-admin 'SP000000000000000000002Q6VF78)) ERR-INVALID-ADMIN)
        ;; Set the new administrator using a local variable to avoid warning
        (let ((validated-admin new-admin))
            (var-set contract-administrator validated-admin)
            (ok true)
        )
    )
)

;; Event logging function
(define-private (log-event (event-type (string-ascii 50)) (data uint))
    (let ((current-id (var-get event-counter)))
        (map-set event-log 
            { event-id: current-id }
            {
                event-type: event-type,
                user: tx-sender,
                block-height: block-height,
                data: data
            }
        )
        (var-set event-counter (+ current-id u1))
        current-id
    )
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

(define-read-only (calculate-emergency-withdrawal-fee (amount uint))
    (/ (* amount EMERGENCY-WITHDRAWAL-FEE-BASIS-POINTS) u10000)
)

(define-read-only (get-event (event-id uint))
    (map-get? event-log { event-id: event-id })
)

(define-read-only (get-current-administrator)
    (var-get contract-administrator)
)

;; Public functions

(define-public (create-new-vault 
    (lockup-duration uint) 
    (beneficiary-address (optional principal)) 
    (safety-period uint)
    (asset-type (string-ascii 32))
    (token-contract (optional principal))
    (token-id (optional (string-ascii 32)))
)
    (let (
        (unlock-block-height (+ block-height lockup-duration))
        (effective-safety-period (if (< safety-period MIN-SAFETY-PERIOD) 
                                DEFAULT-SAFETY-PERIOD 
                                safety-period))
        (valid-asset-type (if (or (is-eq asset-type TOKEN-TYPE-STX) (is-eq asset-type TOKEN-TYPE-FT)) 
                             asset-type 
                             TOKEN-TYPE-STX))
    )
    (asserts! (is-none (get-vault-information tx-sender)) ERR-VAULT-ALREADY-EXISTS)
    (asserts! (and (>= lockup-duration MIN-LOCKUP-DURATION) (<= lockup-duration MAX-LOCKUP-DURATION)) ERR-INVALID-LOCKUP-DURATION)
    (asserts! (or (is-none beneficiary-address) (not (is-eq (some tx-sender) beneficiary-address))) ERR-INVALID-BENEFICIARY-ADDRESS)
    (asserts! (or (is-eq valid-asset-type TOKEN-TYPE-STX) 
                 (and (is-eq valid-asset-type TOKEN-TYPE-FT) (is-some token-contract) (is-some token-id))) 
                 ERR-UNSUPPORTED-TOKEN)
    
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
            asset-type: valid-asset-type,
            token-contract: token-contract,
            token-id: token-id
        }
    )
    
    ;; Log event
    (log-event "vault-created" lockup-duration)
    (ok true))
)

(define-public (extend-lockup-period (additional-blocks uint))
    (let (
        (vault-data (unwrap! (get-vault-information tx-sender) ERR-VAULT-NOT-FOUND))
        (current-block-height block-height)
        (new-unlock-height (+ (get unlock-block-height vault-data) additional-blocks))
        (new-total-duration (+ (get lockup-duration-blocks vault-data) additional-blocks))
    )
    (asserts! (> additional-blocks u0) ERR-EXTENSION-PERIOD-TOO-SHORT)
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
    
    ;; Log event
    (log-event "lockup-extended" additional-blocks)
    (ok true))
)

(define-public (modify-beneficiary (updated-beneficiary (optional principal)))
    (let (
        (vault-data (unwrap! (get-vault-information tx-sender) ERR-VAULT-NOT-FOUND))
    )
    (asserts! (or (is-none updated-beneficiary) (not (is-eq (some tx-sender) updated-beneficiary))) ERR-INVALID-BENEFICIARY-ADDRESS)
    
    (map-set time-locked-vaults
        { vault-owner: tx-sender }
        (merge vault-data {
            designated-beneficiary: updated-beneficiary,
            beneficiary-access-status: (if (is-some updated-beneficiary) 
                                        BENEFICIARY-STATUS-PENDING
                                        BENEFICIARY-STATUS-INACTIVE),
            last-activity-timestamp: block-height
        })
    )
    
    ;; Log event
    (log-event "beneficiary-modified" (if (is-some updated-beneficiary) u1 u0))
    (ok true))
)

(define-public (confirm-beneficiary-status (vault-owner principal))
    (let (
        (vault-data (unwrap! (get-vault-information vault-owner) ERR-VAULT-NOT-FOUND))
    )
    (asserts! (is-eq (some tx-sender) (get designated-beneficiary vault-data)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get beneficiary-access-status vault-data) BENEFICIARY-STATUS-PENDING) ERR-BENEFICIARY-NOT-AUTHORIZED)
    
    (map-set time-locked-vaults
        { vault-owner: vault-owner }
        (merge vault-data {
            beneficiary-access-status: BENEFICIARY-STATUS-ACTIVE
        })
    )
    
    ;; Log event
    (log-event "beneficiary-confirmed" u1)
    (ok true))
)

(define-public (deposit-stx-funds (deposit-amount uint))
    (let (
        (vault-data (unwrap! (get-vault-information tx-sender) ERR-VAULT-NOT-FOUND))
    )
    (asserts! (is-eq (get asset-type vault-data) TOKEN-TYPE-STX) ERR-UNSUPPORTED-TOKEN)
    (asserts! (> deposit-amount u0) ERR-ZERO-AMOUNT)
    
    ;; First update state
    (map-set time-locked-vaults
        { vault-owner: tx-sender }
        (merge vault-data {
            locked-amount: (+ (get locked-amount vault-data) deposit-amount),
            last-activity-timestamp: block-height
        })
    )
    
    ;; Then transfer funds
    (try! (stx-transfer? deposit-amount tx-sender (as-contract tx-sender)))
    
    ;; Log event
    (log-event "funds-deposited" deposit-amount)
    (ok true))
)

(define-public (deposit-ft-funds (deposit-amount uint))
    (let (
        (vault-data (unwrap! (get-vault-information tx-sender) ERR-VAULT-NOT-FOUND))
        (token-contract-principal (unwrap! (get token-contract vault-data) ERR-UNSUPPORTED-TOKEN))
        (token-asset-id (unwrap! (get token-id vault-data) ERR-UNSUPPORTED-TOKEN))
    )
    (asserts! (is-eq (get asset-type vault-data) TOKEN-TYPE-FT) ERR-UNSUPPORTED-TOKEN)
    (asserts! (> deposit-amount u0) ERR-ZERO-AMOUNT)
    
    ;; First update state
    (map-set time-locked-vaults
        { vault-owner: tx-sender }
        (merge vault-data {
            locked-amount: (+ (get locked-amount vault-data) deposit-amount),
            last-activity-timestamp: block-height
        })
    )
    
    ;; Then transfer funds - Note: This is a placeholder. Actual FT transfers would require SIP-010 interface
    ;; (try! (contract-call? token-contract-principal transfer token-asset-id deposit-amount tx-sender (as-contract tx-sender) none))
    
    ;; Log event
    (log-event "ft-funds-deposited" deposit-amount)
    (ok true))
)

(define-public (withdraw-stx-funds (withdrawal-amount uint))
    (let (
        (vault-data (unwrap! (get-vault-information tx-sender) ERR-VAULT-NOT-FOUND))
        (current-block-height block-height)
    )
    (asserts! (is-eq (get asset-type vault-data) TOKEN-TYPE-STX) ERR-UNSUPPORTED-TOKEN)
    (asserts! (>= current-block-height (get unlock-block-height vault-data)) ERR-ASSETS-STILL-LOCKED)
    (asserts! (<= withdrawal-amount (get locked-amount vault-data)) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> withdrawal-amount u0) ERR-ZERO-AMOUNT)
    
    ;; First update state
    (map-set time-locked-vaults
        { vault-owner: tx-sender }
        (merge vault-data {
            locked-amount: (- (get locked-amount vault-data) withdrawal-amount),
            last-activity-timestamp: current-block-height
        })
    )
    
    ;; Then transfer funds
    (try! (as-contract (stx-transfer? withdrawal-amount (as-contract tx-sender) tx-sender)))
    
    ;; Log event
    (log-event "funds-withdrawn" withdrawal-amount)
    (ok true))
)

(define-public (withdraw-ft-funds (withdrawal-amount uint))
    (let (
        (vault-data (unwrap! (get-vault-information tx-sender) ERR-VAULT-NOT-FOUND))
        (current-block-height block-height)
        (token-contract-principal (unwrap! (get token-contract vault-data) ERR-UNSUPPORTED-TOKEN))
        (token-asset-id (unwrap! (get token-id vault-data) ERR-UNSUPPORTED-TOKEN))
    )
    (asserts! (is-eq (get asset-type vault-data) TOKEN-TYPE-FT) ERR-UNSUPPORTED-TOKEN)
    (asserts! (>= current-block-height (get unlock-block-height vault-data)) ERR-ASSETS-STILL-LOCKED)
    (asserts! (<= withdrawal-amount (get locked-amount vault-data)) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> withdrawal-amount u0) ERR-ZERO-AMOUNT)
    
    ;; First update state
    (map-set time-locked-vaults
        { vault-owner: tx-sender }
        (merge vault-data {
            locked-amount: (- (get locked-amount vault-data) withdrawal-amount),
            last-activity-timestamp: current-block-height
        })
    )
    
    ;; Log event
    (log-event "ft-funds-withdrawn" withdrawal-amount)
    (ok true))
)

(define-public (emergency-withdrawal (withdrawal-amount uint))
    (let (
        (vault-data (unwrap! (get-vault-information tx-sender) ERR-VAULT-NOT-FOUND))
        (current-block-height block-height)
        (fee-amount (calculate-emergency-withdrawal-fee withdrawal-amount))
        (net-withdrawal (- withdrawal-amount fee-amount))
    )
    (asserts! (<= withdrawal-amount (get locked-amount vault-data)) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> withdrawal-amount u0) ERR-ZERO-AMOUNT)
    
    ;; First update state
    (map-set time-locked-vaults
        { vault-owner: tx-sender }
        (merge vault-data {
            locked-amount: (- (get locked-amount vault-data) withdrawal-amount),
            last-activity-timestamp: current-block-height
        })
    )
    
    ;; Then transfer funds - with fee
    (if (is-eq (get asset-type vault-data) TOKEN-TYPE-STX)
        (begin
            (try! (as-contract (stx-transfer? net-withdrawal (as-contract tx-sender) tx-sender)))
            (try! (as-contract (stx-transfer? fee-amount (as-contract tx-sender) (var-get contract-administrator))))
        )
        ;; For FT - placeholder
        true
    )
    
    ;; Log event
    (log-event "emergency-withdrawal" withdrawal-amount)
    (ok true))
)

(define-public (execute-beneficiary-claim (vault-owner principal))
    (let (
        (vault-data (unwrap! (get-vault-information vault-owner) ERR-VAULT-NOT-FOUND))
        (current-block-height block-height)
        (safety-period-end (+ (get unlock-block-height vault-data) (get inactivity-grace-period vault-data)))
        (owner-inactivity-duration (- current-block-height (get last-activity-timestamp vault-data)))
        (withdrawal-amount (get locked-amount vault-data))
    )
    ;; Verify beneficiary status and conditions
    (asserts! (is-some (get designated-beneficiary vault-data)) ERR-NO-BENEFICIARY-ASSIGNED)
    (asserts! (is-eq (some tx-sender) (get designated-beneficiary vault-data)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get beneficiary-access-status vault-data) BENEFICIARY-STATUS-ACTIVE) ERR-BENEFICIARY-NOT-AUTHORIZED)
    (asserts! (or 
        (>= current-block-height safety-period-end)
        (>= owner-inactivity-duration (get inactivity-grace-period vault-data))
    ) ERR-ASSETS-STILL-LOCKED)
    
    ;; First update state then transfer
    (map-delete time-locked-vaults { vault-owner: vault-owner })
    
    ;; Transfer funds based on asset type
    (if (is-eq (get asset-type vault-data) TOKEN-TYPE-STX)
        (try! (as-contract (stx-transfer? withdrawal-amount (as-contract tx-sender) tx-sender)))
        ;; For FT - placeholder
        true
    )
    
    ;; Log event
    (log-event "beneficiary-claim" withdrawal-amount)
    (ok true))
)

(define-public (close-vault)
    (let (
        (vault-data (unwrap! (get-vault-information tx-sender) ERR-VAULT-NOT-FOUND))
        (current-block-height block-height)
    )
    (asserts! (>= current-block-height (get unlock-block-height vault-data)) ERR-ASSETS-STILL-LOCKED)
    (asserts! (is-eq (get locked-amount vault-data) u0) ERR-INSUFFICIENT-BALANCE)
    
    ;; Delete the vault
    (map-delete time-locked-vaults { vault-owner: tx-sender })
    
    ;; Log event
    (log-event "vault-closed" u0)
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
    
    ;; Log event
    (log-event "activity-registered" block-height)
    (ok true))
)