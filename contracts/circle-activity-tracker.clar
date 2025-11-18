(define-map circle-activity-history
  { circle-id: uint, activity-id: uint }
  {
    activity-type: (string-ascii 20),
    member: principal,
    cycle: uint,
    amount: uint,
    block-height: uint,
    success: bool
  }
)

(define-map activity-counters
  { circle-id: uint }
  { counter: uint }
)

(define-map circle-statistics
  { circle-id: uint }
  {
    total-contributions: uint,
    successful-cycles: uint,
    failed-cycles: uint,
    total-volume: uint,
    completion-rate: uint,
    average-contribution-time: uint,
    last-updated: uint
  }
)

(define-read-only (get-activity-counter (circle-id uint))
  (match (map-get? activity-counters { circle-id: circle-id })
    counter-data (get counter counter-data)
    u0
  )
)

(define-read-only (get-circle-activity-history (circle-id uint) (activity-id uint))
  (map-get? circle-activity-history { circle-id: circle-id, activity-id: activity-id })
)

(define-read-only (get-circle-statistics (circle-id uint))
  (match (map-get? circle-statistics { circle-id: circle-id })
    stats-data stats-data
    {
      total-contributions: u0,
      successful-cycles: u0,
      failed-cycles: u0,
      total-volume: u0,
      completion-rate: u0,
      average-contribution-time: u0,
      last-updated: u0
    }
  )
)

(define-private (record-activity (circle-id uint) (activity-type (string-ascii 20)) (member principal) (cycle uint) (amount uint) (success bool))
  (let
    (
      (activity-id (+ (get-activity-counter circle-id) u1))
    )
    (map-set circle-activity-history
      { circle-id: circle-id, activity-id: activity-id }
      {
        activity-type: activity-type,
        member: member,
        cycle: cycle,
        amount: amount,
        block-height: stacks-block-height,
        success: success
      }
    )
    (map-set activity-counters
      { circle-id: circle-id }
      { counter: activity-id }
    )
    activity-id
  )
)

(define-public (track-contribution (circle-id uint) (member principal) (cycle uint) (amount uint))
  (let
    (
      (activity-id (record-activity circle-id "contribution" member cycle amount true))
      (stats-updated (update-circle-statistics circle-id "contribution" amount))
    )
    (ok true)
  )
)

(define-public (track-cycle-completion (circle-id uint) (cycle uint) (total-amount uint) (success bool))
  (let
    (
      (activity-id (record-activity circle-id "cycle-complete" tx-sender cycle total-amount success))
      (stats-updated (update-circle-statistics circle-id "cycle-complete" total-amount))
    )
    (ok true)
  )
)

(define-private (update-circle-statistics (circle-id uint) (activity-type (string-ascii 20)) (amount uint))
  (let
    (
      (current-stats (get-circle-statistics circle-id))
      (new-contributions (if (is-eq activity-type "contribution") 
        (+ (get total-contributions current-stats) u1) 
        (get total-contributions current-stats)
      ))
      (new-successful-cycles (if (and (is-eq activity-type "cycle-complete") (> amount u0))
        (+ (get successful-cycles current-stats) u1)
        (get successful-cycles current-stats)
      ))
      (new-volume (+ (get total-volume current-stats) amount))
      (new-completion-rate (if (> new-contributions u0)
        (/ (* new-successful-cycles u100) new-contributions)
        u0
      ))
    )
    (map-set circle-statistics
      { circle-id: circle-id }
      {
        total-contributions: new-contributions,
        successful-cycles: new-successful-cycles,
        failed-cycles: (get failed-cycles current-stats),
        total-volume: new-volume,
        completion-rate: new-completion-rate,
        average-contribution-time: (get average-contribution-time current-stats),
        last-updated: stacks-block-height
      }
    )
    true
  )
)
