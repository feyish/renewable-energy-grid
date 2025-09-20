;; Grid Balancing Contract
;; Automatically balance energy supply and demand across the microgrid

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u601))
(define-constant ERR-GRID-UNSTABLE (err u602))
(define-constant ERR-INSUFFICIENT-CAPACITY (err u603))
(define-constant ERR-EMERGENCY-ACTIVE (err u604))

;; Constants
(define-constant BALANCE-THRESHOLD u5000) ;; 5kWh imbalance threshold
(define-constant EMERGENCY-THRESHOLD u10000) ;; 10kWh emergency threshold
(define-constant STABILITY-FACTOR u95) ;; 95% minimum stability

;; Data variables
(define-data-var total-supply uint u0)
(define-data-var total-demand uint u0)
(define-data-var grid-stability uint u100)
(define-data-var emergency-mode bool false)
(define-data-var last-balance-check uint u0)

;; Data maps
(define-map grid-nodes
    principal
    {
        node-type: (string-ascii 10), ;; "producer", "consumer", "storage"
        capacity: uint,
        current-load: uint,
        priority-level: uint,
        is-active: bool,
        last-update: uint
    }
)

(define-map balance-events
    uint ;; event-id
    {
        event-type: (string-ascii 20), ;; "rebalance", "emergency", "recovery"
        supply-before: uint,
        demand-before: uint,
        supply-after: uint,
        demand-after: uint,
        timestamp: uint,
        actions-taken: (list 5 (string-ascii 50))
    }
)

;; Private functions
(define-private (calculate-grid-balance)
    (let 
        (
            (supply (var-get total-supply))
            (demand (var-get total-demand))
        )
        (if (>= supply demand)
            (- supply demand)
            (- demand supply)
        )
    )
)

(define-private (update-grid-stability)
    (let 
        (
            (balance (calculate-grid-balance))
            (stability 
                (if (< balance BALANCE-THRESHOLD)
                    u100
                    (if (< balance EMERGENCY-THRESHOLD)
                        u75
                        u50
                    )
                )
            )
        )
        (var-set grid-stability stability)
        stability
    )
)

;; Read-only functions
(define-read-only (get-grid-status)
    {
        supply: (var-get total-supply),
        demand: (var-get total-demand),
        balance: (calculate-grid-balance),
        stability: (var-get grid-stability),
        emergency-mode: (var-get emergency-mode)
    }
)

(define-read-only (get-grid-node (node principal))
    (map-get? grid-nodes node)
)

(define-read-only (is-grid-balanced)
    (< (calculate-grid-balance) BALANCE-THRESHOLD)
)

;; Public functions
(define-public (register-grid-node (node-type (string-ascii 10)) (capacity uint))
    (begin
        (map-set grid-nodes tx-sender
            {
                node-type: node-type,
                capacity: capacity,
                current-load: u0,
                priority-level: u50, ;; Medium priority by default
                is-active: true,
                last-update: block-height
            }
        )
        (ok true)
    )
)

(define-public (update-node-load (new-load uint))
    (let 
        (
            (node-data (unwrap! (map-get? grid-nodes tx-sender) ERR-UNAUTHORIZED))
        )
        (asserts! (get is-active node-data) ERR-UNAUTHORIZED)
        (asserts! (<= new-load (get capacity node-data)) ERR-INSUFFICIENT-CAPACITY)
        
        ;; Update node load
        (map-set grid-nodes tx-sender
            (merge node-data {
                current-load: new-load,
                last-update: block-height
            })
        )
        
        ;; Update global supply/demand based on node type
        (if (is-eq (get node-type node-data) "producer")
            (var-set total-supply (+ (var-get total-supply) new-load))
            (var-set total-demand (+ (var-get total-demand) new-load))
        )
        
        ;; Update balance check timestamp
        (var-set last-balance-check block-height)
        
        (ok true)
    )
)

(define-public (trigger-balance-check)
    (let 
        (
            (balance (calculate-grid-balance))
            (stability (update-grid-stability))
        )
        (var-set last-balance-check block-height)
        
        (if (>= balance EMERGENCY-THRESHOLD)
            (begin
                (var-set emergency-mode true)
                (ok "Emergency mode activated")
            )
            (if (>= balance BALANCE-THRESHOLD)
                (ok "Normal rebalancing triggered")
                (ok "Grid balanced")
            )
        )
    )
)

(define-public (emergency-rebalance)
    ;; Simplified emergency rebalancing logic
    (begin
        ;; In a real implementation, this would:
        ;; 1. Prioritize critical loads
        ;; 2. Shed non-essential loads
        ;; 3. Activate emergency storage
        ;; 4. Request external grid support
        
        (var-set emergency-mode true)
        (var-set grid-stability u50)
        
        (ok "Emergency rebalancing activated")
    )
)

(define-public (normal-rebalance)
    ;; Simplified normal rebalancing logic
    (begin
        ;; In a real implementation, this would:
        ;; 1. Optimize energy distribution
        ;; 2. Activate demand response programs
        ;; 3. Balance storage charging/discharging
        ;; 4. Adjust pricing signals
        
        (update-grid-stability)
        
        (ok "Normal rebalancing completed")
    )
)

(define-public (deactivate-node)
    (let 
        (
            (node-data (unwrap! (map-get? grid-nodes tx-sender) ERR-UNAUTHORIZED))
        )
        (map-set grid-nodes tx-sender
            (merge node-data {
                is-active: false,
                current-load: u0,
                last-update: block-height
            })
        )
        
        ;; Update global supply/demand
        (if (is-eq (get node-type node-data) "producer")
            (var-set total-supply (- (var-get total-supply) (get current-load node-data)))
            (var-set total-demand (- (var-get total-demand) (get current-load node-data)))
        )
        
        (ok true)
    )
)

