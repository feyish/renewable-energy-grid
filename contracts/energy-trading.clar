;; Energy Trading Contract
;; Enable direct trading of excess energy between grid participants

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u501))
(define-constant ERR-ORDER-NOT-FOUND (err u502))
(define-constant ERR-INSUFFICIENT-ENERGY (err u503))
(define-constant ERR-ORDER-EXPIRED (err u504))
(define-constant ERR-INVALID-PRICE (err u505))
(define-constant ERR-CANNOT-MATCH-OWN-ORDER (err u506))

;; Constants
(define-constant MIN-ENERGY-AMOUNT u1000) ;; 1kWh minimum
(define-constant MAX-ENERGY-AMOUNT u1000000) ;; 1MWh maximum
(define-constant ORDER-DURATION u144) ;; ~24 hours

;; Data variables
(define-data-var order-counter uint u0)
(define-data-var total-traded uint u0)

;; Data maps
(define-map energy-orders
    uint ;; order-id
    {
        seller: principal,
        buyer: (optional principal),
        energy-amount: uint,
        price-per-kwh: uint,
        order-type: (string-ascii 4), ;; "sell" or "buy"
        status: (string-ascii 10), ;; "active", "matched", "completed", "cancelled"
        created-at: uint,
        expires-at: uint,
        matched-at: (optional uint)
    }
)

(define-map user-balances
    principal
    uint ;; available energy in watt-hours
)

;; Private functions
(define-private (get-next-order-id)
    (let ((current-id (var-get order-counter)))
        (var-set order-counter (+ current-id u1))
        (+ current-id u1)
    )
)

;; Read-only functions
(define-read-only (get-order (order-id uint))
    (map-get? energy-orders order-id)
)

(define-read-only (get-user-balance (user principal))
    (default-to u0 (map-get? user-balances user))
)

(define-read-only (get-total-traded)
    (var-get total-traded)
)

;; Public functions
(define-public (create-sell-order (energy-amount uint) (price-per-kwh uint))
    (let 
        (
            (order-id (get-next-order-id))
            (user-balance (get-user-balance tx-sender))
        )
        (asserts! (and (>= energy-amount MIN-ENERGY-AMOUNT) (<= energy-amount MAX-ENERGY-AMOUNT)) ERR-INSUFFICIENT-ENERGY)
        (asserts! (>= user-balance energy-amount) ERR-INSUFFICIENT-ENERGY)
        (asserts! (> price-per-kwh u0) ERR-INVALID-PRICE)
        
        (map-set energy-orders order-id
            {
                seller: tx-sender,
                buyer: none,
                energy-amount: energy-amount,
                price-per-kwh: price-per-kwh,
                order-type: "sell",
                status: "active",
                created-at: block-height,
                expires-at: (+ block-height ORDER-DURATION),
                matched-at: none
            }
        )
        
        ;; Reserve energy
        (map-set user-balances tx-sender (- user-balance energy-amount))
        
        (ok order-id)
    )
)

(define-public (match-order (order-id uint))
    (let 
        (
            (order (unwrap! (map-get? energy-orders order-id) ERR-ORDER-NOT-FOUND))
            (total-cost (* (get energy-amount order) (get price-per-kwh order)))
        )
        (asserts! (is-eq (get status order) "active") ERR-ORDER-EXPIRED)
        (asserts! (< block-height (get expires-at order)) ERR-ORDER-EXPIRED)
        (asserts! (not (is-eq tx-sender (get seller order))) ERR-CANNOT-MATCH-OWN-ORDER)
        
        ;; Process payment (simplified - in production would use proper STX transfer)
        ;; Transfer energy to buyer
        (let ((buyer-balance (get-user-balance tx-sender)))
            (map-set user-balances tx-sender (+ buyer-balance (get energy-amount order)))
        )
        
        ;; Update order status
        (map-set energy-orders order-id
            (merge order {
                buyer: (some tx-sender),
                status: "matched",
                matched-at: (some block-height)
            })
        )
        
        ;; Update global stats
        (var-set total-traded (+ (var-get total-traded) (get energy-amount order)))
        
        (ok true)
    )
)

(define-public (add-energy-balance (amount uint))
    ;; Simplified - in production would integrate with energy-production contract
    (let ((current-balance (get-user-balance tx-sender)))
        (map-set user-balances tx-sender (+ current-balance amount))
        (ok true)
    )
)


;; title: energy-trading
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

