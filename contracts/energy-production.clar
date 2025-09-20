;; Energy Production Contract
;; Track and verify renewable energy production from homes and businesses

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-PRODUCER-NOT-FOUND (err u402))
(define-constant ERR-ALREADY-REGISTERED (err u403))
(define-constant ERR-INVALID-CAPACITY (err u404))
(define-constant ERR-INVALID-SOURCE-TYPE (err u405))
(define-constant ERR-INSUFFICIENT-PRODUCTION (err u406))
(define-constant ERR-INVALID-AMOUNT (err u407))
(define-constant ERR-NOT-VERIFIED (err u408))

;; Constants
(define-constant MIN-CAPACITY u100) ;; Minimum 100W capacity
(define-constant MAX-CAPACITY u1000000) ;; Maximum 1MW capacity
(define-constant PRODUCTION-REWARD-RATE u10) ;; 10 microSTX per kWh
(define-constant VERIFICATION-THRESHOLD u1000) ;; 1kW threshold for verification

;; Data variables
(define-data-var producer-counter uint u0)
(define-data-var total-production uint u0)
(define-data-var total-capacity uint u0)

;; Data maps
(define-map producers
    principal
    {
        producer-id: uint,
        capacity: uint, ;; in watts
        source-type: (string-ascii 20),
        total-production: uint, ;; in watt-hours
        monthly-production: uint,
        last-report-block: uint,
        is-verified: bool,
        registration-date: uint,
        status: (string-ascii 10) ;; "active", "inactive", "suspended"
    }
)

(define-map production-reports
    { producer: principal, report-id: uint }
    {
        amount: uint, ;; in watt-hours
        timestamp: uint,
        verified: bool,
        meter-reading: (optional uint),
        source-verified: bool
    }
)

(define-map energy-certificates
    uint ;; certificate-id
    {
        producer: principal,
        energy-amount: uint,
        production-period: uint,
        issue-date: uint,
        is-traded: bool,
        carbon-offset: uint
    }
)

(define-map monthly-stats
    { producer: principal, month: uint, year: uint }
    {
        total-production: uint,
        average-daily: uint,
        peak-production: uint,
        days-active: uint,
        efficiency-rating: uint
    }
)

;; Private functions
(define-private (get-next-producer-id)
    (let ((current-id (var-get producer-counter)))
        (var-set producer-counter (+ current-id u1))
        (+ current-id u1)
    )
)

(define-private (is-valid-source-type (source-type (string-ascii 20)))
    (or 
        (is-eq source-type "solar")
        (is-eq source-type "wind")
        (is-eq source-type "hydro")
        (is-eq source-type "battery")
        (is-eq source-type "biomass")
    )
)

(define-private (calculate-production-rewards (amount uint))
    (* amount PRODUCTION-REWARD-RATE)
)

(define-private (update-total-stats (capacity uint) (production uint))
    (begin
        (var-set total-capacity (+ (var-get total-capacity) capacity))
        (var-set total-production (+ (var-get total-production) production))
        true
    )
)

(define-private (get-current-month)
    (/ block-height u4320) ;; Approximate blocks per month
)

(define-private (get-current-year)
    (/ block-height u51840) ;; Approximate blocks per year
)

;; Read-only functions
(define-read-only (get-producer (producer principal))
    (map-get? producers producer)
)

(define-read-only (get-production-report (producer principal) (report-id uint))
    (map-get? production-reports { producer: producer, report-id: report-id })
)

(define-read-only (get-total-production)
    (var-get total-production)
)

(define-read-only (get-total-capacity)
    (var-get total-capacity)
)

(define-read-only (get-producer-count)
    (var-get producer-counter)
)

(define-read-only (is-producer-verified (producer principal))
    (match (map-get? producers producer)
        producer-data (get is-verified producer-data)
        false
    )
)

(define-read-only (get-monthly-stats (producer principal) (month uint) (year uint))
    (map-get? monthly-stats { producer: producer, month: month, year: year })
)

(define-read-only (calculate-efficiency (producer principal))
    (match (map-get? producers producer)
        producer-data
            (let 
                (
                    (capacity (get capacity producer-data))
                    (production (get total-production producer-data))
                    (blocks-active (- block-height (get registration-date producer-data)))
                )
                (if (> blocks-active u0)
                    (/ (* production u100) (* capacity blocks-active))
                    u0
                )
            )
        u0
    )
)

;; Public functions
(define-public (register-producer (capacity uint) (source-type (string-ascii 20)))
    (let 
        (
            (producer-id (get-next-producer-id))
            (existing-producer (map-get? producers tx-sender))
        )
        (asserts! (is-none existing-producer) ERR-ALREADY-REGISTERED)
        (asserts! (and (>= capacity MIN-CAPACITY) (<= capacity MAX-CAPACITY)) ERR-INVALID-CAPACITY)
        (asserts! (is-valid-source-type source-type) ERR-INVALID-SOURCE-TYPE)
        
        (map-set producers tx-sender
            {
                producer-id: producer-id,
                capacity: capacity,
                source-type: source-type,
                total-production: u0,
                monthly-production: u0,
                last-report-block: block-height,
                is-verified: (>= capacity VERIFICATION-THRESHOLD),
                registration-date: block-height,
                status: "active"
            }
        )
        
        ;; Update global stats
        (update-total-stats capacity u0)
        
        (ok producer-id)
    )
)

(define-public (report-production (amount uint))
    (let 
        (
            (producer-data (unwrap! (map-get? producers tx-sender) ERR-PRODUCER-NOT-FOUND))
            (report-id (get-next-producer-id))
        )
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (is-eq (get status producer-data) "active") ERR-UNAUTHORIZED)
        
        ;; Record production report
        (map-set production-reports 
            { producer: tx-sender, report-id: report-id }
            {
                amount: amount,
                timestamp: block-height,
                verified: false, ;; Will be verified later
                meter-reading: none,
                source-verified: true
            }
        )
        
        ;; Update producer stats
        (map-set producers tx-sender
            (merge producer-data {
                total-production: (+ (get total-production producer-data) amount),
                monthly-production: (+ (get monthly-production producer-data) amount),
                last-report-block: block-height
            })
        )
        
        ;; Update global production
        (var-set total-production (+ (var-get total-production) amount))
        
        ;; Update monthly stats
        (update-monthly-stats tx-sender amount)
        
        (ok report-id)
    )
)

(define-public (verify-production (producer principal) (report-id uint) (verified bool))
    ;; In a real implementation, this would be called by oracles or verification nodes
    (let 
        (
            (report (unwrap! (map-get? production-reports { producer: producer, report-id: report-id }) ERR-PRODUCER-NOT-FOUND))
        )
        ;; For simplicity, allow anyone to verify for now
        ;; In production, this would require proper authorization
        
        (map-set production-reports { producer: producer, report-id: report-id }
            (merge report { verified: verified })
        )
        
        (ok true)
    )
)

(define-public (update-producer-capacity (new-capacity uint))
    (let 
        (
            (producer-data (unwrap! (map-get? producers tx-sender) ERR-PRODUCER-NOT-FOUND))
            (old-capacity (get capacity producer-data))
        )
        (asserts! (and (>= new-capacity MIN-CAPACITY) (<= new-capacity MAX-CAPACITY)) ERR-INVALID-CAPACITY)
        (asserts! (is-eq (get status producer-data) "active") ERR-UNAUTHORIZED)
        
        ;; Update capacity
        (map-set producers tx-sender
            (merge producer-data {
                capacity: new-capacity,
                is-verified: (>= new-capacity VERIFICATION-THRESHOLD)
            })
        )
        
        ;; Update global capacity
        (var-set total-capacity 
            (+ (- (var-get total-capacity) old-capacity) new-capacity)
        )
        
        (ok true)
    )
)

(define-public (deactivate-producer)
    (let 
        (
            (producer-data (unwrap! (map-get? producers tx-sender) ERR-PRODUCER-NOT-FOUND))
        )
        (asserts! (is-eq (get status producer-data) "active") ERR-UNAUTHORIZED)
        
        ;; Deactivate producer
        (map-set producers tx-sender
            (merge producer-data { status: "inactive" })
        )
        
        ;; Remove capacity from global stats
        (var-set total-capacity 
            (- (var-get total-capacity) (get capacity producer-data))
        )
        
        (ok true)
    )
)

(define-public (reactivate-producer)
    (let 
        (
            (producer-data (unwrap! (map-get? producers tx-sender) ERR-PRODUCER-NOT-FOUND))
        )
        (asserts! (is-eq (get status producer-data) "inactive") ERR-UNAUTHORIZED)
        
        ;; Reactivate producer
        (map-set producers tx-sender
            (merge producer-data { status: "active" })
        )
        
        ;; Add capacity back to global stats
        (var-set total-capacity 
            (+ (var-get total-capacity) (get capacity producer-data))
        )
        
        (ok true)
    )
)

(define-public (issue-energy-certificate (producer principal) (energy-amount uint) (carbon-offset uint))
    ;; Simplified certificate issuance - in production would require proper verification
    (let 
        (
            (producer-data (unwrap! (map-get? producers producer) ERR-PRODUCER-NOT-FOUND))
            (certificate-id (get-next-producer-id))
        )
        (asserts! (is-verified-producer producer) ERR-NOT-VERIFIED)
        (asserts! (>= (get total-production producer-data) energy-amount) ERR-INSUFFICIENT-PRODUCTION)
        
        (map-set energy-certificates certificate-id
            {
                producer: producer,
                energy-amount: energy-amount,
                production-period: (get-current-month),
                issue-date: block-height,
                is-traded: false,
                carbon-offset: carbon-offset
            }
        )
        
        (ok certificate-id)
    )
)

;; Private helper functions
(define-private (is-verified-producer (producer principal))
    (match (map-get? producers producer)
        producer-data (get is-verified producer-data)
        false
    )
)

(define-private (update-monthly-stats (producer principal) (production-amount uint))
    (let 
        (
            (current-month (get-current-month))
            (current-year (get-current-year))
            (existing-stats (map-get? monthly-stats 
                { producer: producer, month: current-month, year: current-year }
            ))
        )
        (match existing-stats
            stats
                (map-set monthly-stats 
                    { producer: producer, month: current-month, year: current-year }
                    (merge stats {
                        total-production: (+ (get total-production stats) production-amount),
                        days-active: (+ (get days-active stats) u1)
                    })
                )
            ;; Create new monthly stats
            (map-set monthly-stats 
                { producer: producer, month: current-month, year: current-year }
                {
                    total-production: production-amount,
                    average-daily: production-amount,
                    peak-production: production-amount,
                    days-active: u1,
                    efficiency-rating: u100
                }
            )
        )
        true
    )
)


;; title: energy-production
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

