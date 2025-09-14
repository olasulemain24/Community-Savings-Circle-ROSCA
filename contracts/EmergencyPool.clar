(define-constant ERR-NOT-MEMBER (err u200))
(define-constant ERR-INSUFFICIENT-EMERGENCY-FUNDS (err u201))
(define-constant ERR-REQUEST-NOT-FOUND (err u202))
(define-constant ERR-ALREADY-VOTED (err u203))
(define-constant ERR-REQUEST-ALREADY-PROCESSED (err u204))
(define-constant ERR-INVALID-AMOUNT (err u205))

(define-data-var request-counter uint u0)

(define-map emergency-pools
  { circle-id: uint }
  { total-balance: uint }
)

(define-map emergency-requests
  { request-id: uint }
  {
    circle-id: uint,
    requester: principal,
    amount: uint,
    reason: (string-ascii 200),
    votes-for: uint,
    votes-against: uint,
    is-processed: bool,
    is-approved: bool,
    created-block: uint
  }
)

(define-map emergency-votes
  { request-id: uint, voter: principal }
  { vote: bool }
)

(define-read-only (get-emergency-balance (circle-id uint))
  (match (map-get? emergency-pools { circle-id: circle-id })
    pool-data (get total-balance pool-data)
    u0
  )
)

(define-read-only (get-emergency-request (request-id uint))
  (map-get? emergency-requests { request-id: request-id })
)

(define-public (contribute-to-emergency (circle-id uint) (amount uint))
  (let
    (
      (current-balance (get-emergency-balance circle-id))
      (member-info (contract-call? .CommunitySavings-Circle get-member-info circle-id tx-sender))
    )
    (asserts! (is-some member-info) ERR-NOT-MEMBER)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set emergency-pools
      { circle-id: circle-id }
      { total-balance: (+ current-balance amount) }
    )
    
    (ok true)
  )
)

(define-public (request-emergency-funds (circle-id uint) (amount uint) (reason (string-ascii 200)))
  (let
    (
      (request-id (+ (var-get request-counter) u1))
      (member-info (contract-call? .CommunitySavings-Circle get-member-info circle-id tx-sender))
      (emergency-balance (get-emergency-balance circle-id))
    )
    (asserts! (is-some member-info) ERR-NOT-MEMBER)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount emergency-balance) ERR-INSUFFICIENT-EMERGENCY-FUNDS)
    
    (map-set emergency-requests
      { request-id: request-id }
      {
        circle-id: circle-id,
        requester: tx-sender,
        amount: amount,
        reason: reason,
        votes-for: u0,
        votes-against: u0,
        is-processed: false,
        is-approved: false,
        created-block: stacks-block-height
      }
    )
    
    (var-set request-counter request-id)
    (ok request-id)
  )
)

(define-public (vote-on-request (request-id uint) (vote-for bool))
  (match (get-emergency-request request-id)
    request-data
    (let
      (
        (member-info (contract-call? .CommunitySavings-Circle get-member-info (get circle-id request-data) tx-sender))
        (existing-vote (map-get? emergency-votes { request-id: request-id, voter: tx-sender }))
      )
      (asserts! (is-some member-info) ERR-NOT-MEMBER)
      (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
      (asserts! (not (get is-processed request-data)) ERR-REQUEST-ALREADY-PROCESSED)
      
      (map-set emergency-votes
        { request-id: request-id, voter: tx-sender }
        { vote: vote-for }
      )
      
      (let
        (
          (new-votes-for (if vote-for (+ (get votes-for request-data) u1) (get votes-for request-data)))
          (new-votes-against (if vote-for (get votes-against request-data) (+ (get votes-against request-data) u1)))
        )
        (map-set emergency-requests
          { request-id: request-id }
          (merge request-data {
            votes-for: new-votes-for,
            votes-against: new-votes-against
          })
        )
        
        (try! (check-and-process-request request-id))
        (ok true)
      )
    )
    ERR-REQUEST-NOT-FOUND
  )
)

(define-private (check-and-process-request (request-id uint))
  (match (get-emergency-request request-id)
    request-data
    (match (contract-call? .CommunitySavings-Circle get-circle (get circle-id request-data))
      circle-data
      (let
        (
          (total-members (get current-members circle-data))
          (required-votes (/ (+ total-members u1) u2))
          (total-votes (+ (get votes-for request-data) (get votes-against request-data)))
        )
        (if (>= total-votes required-votes)
          (let
            (
              (approved (> (get votes-for request-data) (get votes-against request-data)))
            )
            (map-set emergency-requests
              { request-id: request-id }
              (merge request-data {
                is-processed: true,
                is-approved: approved
              })
            )
            
            (if approved
              (process-emergency-withdrawal request-id)
              (ok false)
            )
          )
          (ok false)
        )
      )
      (ok false)
    )
    (ok false)
  )
)

(define-private (process-emergency-withdrawal (request-id uint))
  (match (get-emergency-request request-id)
    request-data
    (let
      (
        (amount (get amount request-data))
        (requester (get requester request-data))
        (circle-id (get circle-id request-data))
        (current-emergency-balance (get-emergency-balance circle-id))
      )
      (asserts! (>= current-emergency-balance amount) ERR-INSUFFICIENT-EMERGENCY-FUNDS)
      
      (try! (as-contract (stx-transfer? amount tx-sender requester)))
      
      (map-set emergency-pools
        { circle-id: circle-id }
        { total-balance: (- current-emergency-balance amount) }
      )
      
      (ok true)
    )
    ERR-REQUEST-NOT-FOUND
  )
)
