(define-constant ERR-NOT-ELIGIBLE (err u300))
(define-constant ERR-INSUFFICIENT-POINTS (err u301))
(define-constant ERR-INVALID-MILESTONE (err u302))
(define-constant ERR-ALREADY-CLAIMED (err u303))

(define-constant MILESTONE-FIRST-CYCLE u100)
(define-constant MILESTONE-PERFECT-ATTENDANCE u250)
(define-constant MILESTONE-FULL-ROTATION u500)
(define-constant MILESTONE-HIGH-VOLUME u1000)

(define-constant POINTS-TO-STX-RATE u100)

(define-map member-rewards
  { member: principal }
  {
    total-points: uint,
    redeemed-points: uint,
    milestones-achieved: uint,
    last-reward-block: uint
  }
)

(define-map circle-milestones
  { circle-id: uint, milestone-type: (string-ascii 30) }
  {
    achieved: bool,
    achieved-block: uint,
    bonus-awarded: uint
  }
)

(define-map milestone-claims
  { circle-id: uint, member: principal, milestone-type: (string-ascii 30) }
  { claimed: bool }
)

(define-data-var reward-pool-balance uint u0)

(define-read-only (get-member-rewards (member principal))
  (match (map-get? member-rewards { member: member })
    reward-data reward-data
    {
      total-points: u0,
      redeemed-points: u0,
      milestones-achieved: u0,
      last-reward-block: u0
    }
  )
)

(define-read-only (get-available-points (member principal))
  (let
    (
      (rewards (get-member-rewards member))
    )
    (- (get total-points rewards) (get redeemed-points rewards))
  )
)

(define-read-only (get-circle-milestone (circle-id uint) (milestone-type (string-ascii 30)))
  (map-get? circle-milestones { circle-id: circle-id, milestone-type: milestone-type })
)

(define-public (award-first-cycle-milestone (circle-id uint) (member principal))
  (let
    (
      (claim-record (map-get? milestone-claims { circle-id: circle-id, member: member, milestone-type: "first-cycle" }))
      (already-claimed (match claim-record
        data (get claimed data)
        false
      ))
    )
    (asserts! (not already-claimed) ERR-ALREADY-CLAIMED)
    (map-set milestone-claims
      { circle-id: circle-id, member: member, milestone-type: "first-cycle" }
      { claimed: true }
    )
    (update-member-points member MILESTONE-FIRST-CYCLE)
  )
)

(define-public (award-perfect-attendance (circle-id uint) (member principal) (cycles-completed uint))
  (let
    (
      (circle-info (unwrap! (contract-call? .CommunitySavings-Circle get-circle circle-id) ERR-INVALID-MILESTONE))
      (max-members (get max-members circle-info))
      (claim-record (map-get? milestone-claims { circle-id: circle-id, member: member, milestone-type: "perfect-attendance" }))
      (already-claimed (match claim-record
        data (get claimed data)
        false
      ))
    )
    (asserts! (>= cycles-completed max-members) ERR-NOT-ELIGIBLE)
    (asserts! (not already-claimed) ERR-ALREADY-CLAIMED)
    (map-set milestone-claims
      { circle-id: circle-id, member: member, milestone-type: "perfect-attendance" }
      { claimed: true }
    )
    (map-set circle-milestones
      { circle-id: circle-id, milestone-type: "perfect-attendance" }
      { achieved: true, achieved-block: stacks-block-height, bonus-awarded: MILESTONE-PERFECT-ATTENDANCE }
    )
    (update-member-points member MILESTONE-PERFECT-ATTENDANCE)
  )
)

(define-public (award-full-rotation (circle-id uint) (member principal))
  (let
    (
      (claim-record (map-get? milestone-claims { circle-id: circle-id, member: member, milestone-type: "full-rotation" }))
      (already-claimed (match claim-record
        data (get claimed data)
        false
      ))
    )
    (asserts! (not already-claimed) ERR-ALREADY-CLAIMED)
    (map-set milestone-claims
      { circle-id: circle-id, member: member, milestone-type: "full-rotation" }
      { claimed: true }
    )
    (map-set circle-milestones
      { circle-id: circle-id, milestone-type: "full-rotation" }
      { achieved: true, achieved-block: stacks-block-height, bonus-awarded: MILESTONE-FULL-ROTATION }
    )
    (update-member-points member MILESTONE-FULL-ROTATION)
  )
)

(define-private (update-member-points (member principal) (points uint))
  (let
    (
      (current-rewards (get-member-rewards member))
      (new-total (+ (get total-points current-rewards) points))
      (new-milestones (+ (get milestones-achieved current-rewards) u1))
    )
    (map-set member-rewards
      { member: member }
      {
        total-points: new-total,
        redeemed-points: (get redeemed-points current-rewards),
        milestones-achieved: new-milestones,
        last-reward-block: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (redeem-reward-points (points uint))
  (let
    (
      (available (get-available-points tx-sender))
      (stx-amount (/ points POINTS-TO-STX-RATE))
      (current-rewards (get-member-rewards tx-sender))
    )
    (asserts! (>= available points) ERR-INSUFFICIENT-POINTS)
    (asserts! (>= (var-get reward-pool-balance) stx-amount) ERR-INSUFFICIENT-POINTS)
    (try! (as-contract (stx-transfer? stx-amount tx-sender tx-sender)))
    (map-set member-rewards
      { member: tx-sender }
      (merge current-rewards {
        redeemed-points: (+ (get redeemed-points current-rewards) points)
      })
    )
    (var-set reward-pool-balance (- (var-get reward-pool-balance) stx-amount))
    (ok stx-amount)
  )
)

(define-public (fund-reward-pool (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set reward-pool-balance (+ (var-get reward-pool-balance) amount))
    (ok true)
  )
)
