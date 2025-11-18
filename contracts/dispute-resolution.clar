(define-constant ERR-NOT-MEMBER (err u400))
(define-constant ERR-INVALID-DISPUTE (err u401))
(define-constant ERR-ALREADY-VOTED (err u402))
(define-constant ERR-DISPUTE-CLOSED (err u403))
(define-constant ERR-INSUFFICIENT-VOTES (err u404))

(define-constant DISPUTE-TYPE-CONTRIBUTION "contribution")
(define-constant DISPUTE-TYPE-PAYOUT "payout")
(define-constant DISPUTE-TYPE-BEHAVIOR "behavior")

(define-constant VOTING-PERIOD u144)

(define-data-var dispute-counter uint u0)

(define-map disputes
  { dispute-id: uint }
  {
    circle-id: uint,
    disputer: principal,
    accused: principal,
    dispute-type: (string-ascii 20),
    description: (string-ascii 200),
    evidence-hash: (optional (buff 32)),
    votes-for: uint,
    votes-against: uint,
    total-votes: uint,
    is-resolved: bool,
    resolution: (optional (string-ascii 50)),
    created-block: uint,
    deadline-block: uint
  }
)

(define-map dispute-votes
  { dispute-id: uint, voter: principal }
  { supported: bool, block-height: uint }
)

(define-map member-dispute-history
  { member: principal }
  { total-disputes: uint, disputes-against: uint, guilty-verdicts: uint }
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes { dispute-id: dispute-id })
)

(define-read-only (get-member-history (member principal))
  (default-to
    { total-disputes: u0, disputes-against: u0, guilty-verdicts: u0 }
    (map-get? member-dispute-history { member: member })
  )
)

(define-public (file-dispute 
  (circle-id uint) 
  (accused principal) 
  (dispute-type (string-ascii 20)) 
  (description (string-ascii 200))
  (evidence-hash (optional (buff 32))))
  (let
    (
      (dispute-id (+ (var-get dispute-counter) u1))
      (member-info (contract-call? .CommunitySavings-Circle get-member-info circle-id tx-sender))
      (accused-info (contract-call? .CommunitySavings-Circle get-member-info circle-id accused))
      (deadline (+ stacks-block-height VOTING-PERIOD))
    )
    (asserts! (is-some member-info) ERR-NOT-MEMBER)
    (asserts! (is-some accused-info) ERR-NOT-MEMBER)
    (map-set disputes
      { dispute-id: dispute-id }
      {
        circle-id: circle-id,
        disputer: tx-sender,
        accused: accused,
        dispute-type: dispute-type,
        description: description,
        evidence-hash: evidence-hash,
        votes-for: u0,
        votes-against: u0,
        total-votes: u0,
        is-resolved: false,
        resolution: none,
        created-block: stacks-block-height,
        deadline-block: deadline
      }
    )
    (update-history tx-sender accused)
    (var-set dispute-counter dispute-id)
    (ok dispute-id)
  )
)

(define-public (vote-on-dispute (dispute-id uint) (support bool))
  (match (get-dispute dispute-id)
    dispute-data
    (let
      (
        (member-info (contract-call? .CommunitySavings-Circle get-member-info (get circle-id dispute-data) tx-sender))
        (existing-vote (map-get? dispute-votes { dispute-id: dispute-id, voter: tx-sender }))
      )
      (asserts! (is-some member-info) ERR-NOT-MEMBER)
      (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
      (asserts! (not (get is-resolved dispute-data)) ERR-DISPUTE-CLOSED)
      (asserts! (< stacks-block-height (get deadline-block dispute-data)) ERR-DISPUTE-CLOSED)
      (map-set dispute-votes
        { dispute-id: dispute-id, voter: tx-sender }
        { supported: support, block-height: stacks-block-height }
      )
      (map-set disputes
        { dispute-id: dispute-id }
        (merge dispute-data {
          votes-for: (if support (+ (get votes-for dispute-data) u1) (get votes-for dispute-data)),
          votes-against: (if support (get votes-against dispute-data) (+ (get votes-against dispute-data) u1)),
          total-votes: (+ (get total-votes dispute-data) u1)
        })
      )
      (ok true)
    )
    ERR-INVALID-DISPUTE
  )
)

(define-public (resolve-dispute (dispute-id uint))
  (match (get-dispute dispute-id)
    dispute-data
    (match (contract-call? .CommunitySavings-Circle get-circle (get circle-id dispute-data))
      circle-data
      (let
        (
          (total-members (get current-members circle-data))
          (required-quorum (/ total-members u2))
          (votes-for (get votes-for dispute-data))
          (votes-against (get votes-against dispute-data))
          (total-votes (get total-votes dispute-data))
          (verdict-guilty (> votes-for votes-against))
        )
        (asserts! (not (get is-resolved dispute-data)) ERR-DISPUTE-CLOSED)
        (asserts! (>= stacks-block-height (get deadline-block dispute-data)) ERR-INSUFFICIENT-VOTES)
        (asserts! (>= total-votes required-quorum) ERR-INSUFFICIENT-VOTES)
        (map-set disputes
          { dispute-id: dispute-id }
          (merge dispute-data {
            is-resolved: true,
            resolution: (some (if verdict-guilty "guilty" "not-guilty"))
          })
        )
        (if verdict-guilty
          (finalize-guilty-verdict (get accused dispute-data))
          (ok false)
        )
      )
      ERR-INVALID-DISPUTE
    )
    ERR-INVALID-DISPUTE
  )
)

(define-private (update-history (disputer principal) (accused principal))
  (let
    (
      (disputer-history (get-member-history disputer))
      (accused-history (get-member-history accused))
    )
    (map-set member-dispute-history
      { member: disputer }
      (merge disputer-history { total-disputes: (+ (get total-disputes disputer-history) u1) })
    )
    (map-set member-dispute-history
      { member: accused }
      (merge accused-history { disputes-against: (+ (get disputes-against accused-history) u1) })
    )
    true
  )
)

(define-private (finalize-guilty-verdict (accused principal))
  (let
    (
      (history (get-member-history accused))
    )
    (map-set member-dispute-history
      { member: accused }
      (merge history { guilty-verdicts: (+ (get guilty-verdicts history) u1) })
    )
    (contract-call? .CommunitySavings-Circle penalize-reputation accused u2)
  )
)
