(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-CIRCLE-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-MEMBER (err u102))
(define-constant ERR-NOT-MEMBER (err u103))
(define-constant ERR-CIRCLE-FULL (err u104))
(define-constant ERR-INVALID-AMOUNT (err u105))
(define-constant ERR-CYCLE-NOT-ACTIVE (err u106))
(define-constant ERR-ALREADY-CONTRIBUTED (err u107))
(define-constant ERR-INSUFFICIENT-BALANCE (err u108))
(define-constant ERR-NOT-RECIPIENT (err u109))
(define-constant ERR-ALREADY-CLAIMED (err u110))
(define-constant ERR-CYCLE-NOT-COMPLETE (err u111))

(define-data-var circle-counter uint u0)

(define-map circles
  { circle-id: uint }
  {
    organizer: principal,
    name: (string-ascii 50),
    contribution-amount: uint,
    cycle-duration: uint,
    max-members: uint,
    current-members: uint,
    is-active: bool,
    current-cycle: uint,
    start-block: uint,
    total-cycles: uint
  }
)

(define-map circle-members
  { circle-id: uint, member: principal }
  {
    is-active: bool,
    join-block: uint,
    position: uint
  }
)

(define-map member-contributions
  { circle-id: uint, member: principal, cycle: uint }
  {
    amount: uint,
    block-height: uint,
    contributed: bool
  }
)

(define-map cycle-recipients
  { circle-id: uint, cycle: uint }
  {
    recipient: principal,
    total-amount: uint,
    claimed: bool
  }
)

(define-map circle-balances
  { circle-id: uint }
  { balance: uint }
)

(define-read-only (get-circle (circle-id uint))
  (map-get? circles { circle-id: circle-id })
)

(define-read-only (get-member-info (circle-id uint) (member principal))
  (map-get? circle-members { circle-id: circle-id, member: member })
)

(define-read-only (get-contribution (circle-id uint) (member principal) (cycle uint))
  (map-get? member-contributions { circle-id: circle-id, member: member, cycle: cycle })
)

(define-read-only (get-cycle-recipient (circle-id uint) (cycle uint))
  (map-get? cycle-recipients { circle-id: circle-id, cycle: cycle })
)

(define-read-only (get-circle-balance (circle-id uint))
  (match (map-get? circle-balances { circle-id: circle-id })
    balance-data
    (get balance balance-data)
    u0
  )
)

(define-read-only (get-current-cycle (circle-id uint))
  (match (get-circle circle-id)
    circle-data
    (let
      (
        (start-block (get start-block circle-data))
        (cycle-duration (get cycle-duration circle-data))
        (current-block stacks-block-height)
      )
      (if (>= current-block start-block)
        (+ u1 (/ (- current-block start-block) cycle-duration))
        u0
      )
    )
    u0
  )
)

(define-read-only (is-cycle-active (circle-id uint) (cycle uint))
  (match (get-circle circle-id)
    circle-data
    (let
      (
        (start-block (get start-block circle-data))
        (cycle-duration (get cycle-duration circle-data))
        (cycle-start-block (+ start-block (* (- cycle u1) cycle-duration)))
        (cycle-end-block (+ cycle-start-block cycle-duration))
        (current-block stacks-block-height)
      )
      (and 
        (>= current-block cycle-start-block)
        (< current-block cycle-end-block)
        (get is-active circle-data)
      )
    )
    false
  )
)

(define-read-only (get-next-recipient (circle-id uint) (cycle uint))
  (match (get-circle circle-id)
    circle-data
    (let
      (
        (total-members (get current-members circle-data))
        (recipient-position (mod (- cycle u1) total-members))
      )
      (get-member-by-position circle-id recipient-position)
    )
    none
  )
)

(define-read-only (get-member-by-position (circle-id uint) (position uint))
  (let
    (
      (result
        (fold find-member-by-position 
          (list tx-sender) 
          { circle-id: circle-id, target-position: position, found: none }
        )
      )
    )
    (get found result)
  )
)

(define-private (find-member-by-position (member principal) (data { circle-id: uint, target-position: uint, found: (optional principal) }))
  (if (is-some (get found data))
    data
    (match (get-member-info (get circle-id data) member)
      member-data
      (if (is-eq (get position member-data) (get target-position data))
        (merge data { found: (some member) })
        data
      )
      data
    )
  )
)

(define-public (create-circle (name (string-ascii 50)) (contribution-amount uint) (cycle-duration uint) (max-members uint))
  (let
    (
      (circle-id (+ (var-get circle-counter) u1))
      (start-block (+ stacks-block-height u1))
    )
    (asserts! (> contribution-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> cycle-duration u0) ERR-INVALID-AMOUNT)
    (asserts! (and (> max-members u1) (<= max-members u50)) ERR-INVALID-AMOUNT)
    
    (map-set circles
      { circle-id: circle-id }
      {
        organizer: tx-sender,
        name: name,
        contribution-amount: contribution-amount,
        cycle-duration: cycle-duration,
        max-members: max-members,
        current-members: u1,
        is-active: true,
        current-cycle: u1,
        start-block: start-block,
        total-cycles: max-members
      }
    )
    
    (map-set circle-members
      { circle-id: circle-id, member: tx-sender }
      {
        is-active: true,
        join-block: stacks-block-height,
        position: u0
      }
    )
    
    (map-set circle-balances
      { circle-id: circle-id }
      { balance: u0 }
    )
    
    (var-set circle-counter circle-id)
    (ok circle-id)
  )
)

(define-public (join-circle (circle-id uint))
  (match (get-circle circle-id)
    circle-data
    (begin
      (asserts! (get is-active circle-data) ERR-CYCLE-NOT-ACTIVE)
      (asserts! (< (get current-members circle-data) (get max-members circle-data)) ERR-CIRCLE-FULL)
      (asserts! (is-none (get-member-info circle-id tx-sender)) ERR-ALREADY-MEMBER)
      
      (let
        (
          (new-member-count (+ (get current-members circle-data) u1))
          (member-position (- new-member-count u1))
        )
        (map-set circles
          { circle-id: circle-id }
          (merge circle-data { current-members: new-member-count })
        )
        
        (map-set circle-members
          { circle-id: circle-id, member: tx-sender }
          {
            is-active: true,
            join-block: stacks-block-height,
            position: member-position
          }
        )
        
        (ok true)
      )
    )
    ERR-CIRCLE-NOT-FOUND
  )
)

(define-public (contribute (circle-id uint) (cycle uint))
  (match (get-circle circle-id)
    circle-data
    (begin
      (asserts! (is-some (get-member-info circle-id tx-sender)) ERR-NOT-MEMBER)
      (asserts! (is-cycle-active circle-id cycle) ERR-CYCLE-NOT-ACTIVE)
      (asserts! (is-none (get-contribution circle-id tx-sender cycle)) ERR-ALREADY-CONTRIBUTED)
      
      (let
        (
          (contribution-amount (get contribution-amount circle-data))
          (current-balance (get-circle-balance circle-id))
        )
        (try! (stx-transfer? contribution-amount tx-sender (as-contract tx-sender)))
        
        (map-set member-contributions
          { circle-id: circle-id, member: tx-sender, cycle: cycle }
          {
            amount: contribution-amount,
            block-height: stacks-block-height,
            contributed: true
          }
        )
        
        (map-set circle-balances
          { circle-id: circle-id }
          { balance: (+ current-balance contribution-amount) }
        )
        
        (try! (check-and-finalize-cycle circle-id cycle))
        (ok true)
      )
    )
    ERR-CIRCLE-NOT-FOUND
  )
)

(define-private (check-and-finalize-cycle (circle-id uint) (cycle uint))
  (match (get-circle circle-id)
    circle-data
    (let
      (
        (total-members (get current-members circle-data))
        (contribution-amount (get contribution-amount circle-data))
        (total-expected (/ (* total-members contribution-amount) u1))
        (current-balance (get-circle-balance circle-id))
      )
      (if (>= current-balance total-expected)
        (let
          (
            (recipient (unwrap! (get-next-recipient circle-id cycle) ERR-NOT-MEMBER))
            (payout-amount total-expected)
          )
          (map-set cycle-recipients
            { circle-id: circle-id, cycle: cycle }
            {
              recipient: recipient,
              total-amount: payout-amount,
              claimed: false
            }
          )
          (ok true)
        )
        (ok false)
      )
    )
    ERR-CIRCLE-NOT-FOUND
  )
)

(define-public (claim-cycle-payout (circle-id uint) (cycle uint))
  (match (get-cycle-recipient circle-id cycle)
    recipient-data
    (begin
      (asserts! (is-eq tx-sender (get recipient recipient-data)) ERR-NOT-RECIPIENT)
      (asserts! (not (get claimed recipient-data)) ERR-ALREADY-CLAIMED)
      
      (let
        (
          (payout-amount (get total-amount recipient-data))
          (current-balance (get-circle-balance circle-id))
        )
        (asserts! (>= current-balance payout-amount) ERR-INSUFFICIENT-BALANCE)
        
        (try! (as-contract (stx-transfer? payout-amount tx-sender (get recipient recipient-data))))
        
        (map-set cycle-recipients
          { circle-id: circle-id, cycle: cycle }
          (merge recipient-data { claimed: true })
        )
        
        (map-set circle-balances
          { circle-id: circle-id }
          { balance: (- current-balance payout-amount) }
        )
        
        (ok payout-amount)
      )
    )
    ERR-NOT-RECIPIENT
  )
)

(define-public (leave-circle (circle-id uint))
  (match (get-member-info circle-id tx-sender)
    member-data
    (begin
      (asserts! (get is-active member-data) ERR-NOT-MEMBER)
      
      (map-set circle-members
        { circle-id: circle-id, member: tx-sender }
        (merge member-data { is-active: false })
      )
      
      (match (get-circle circle-id)
        circle-data
        (if (is-eq tx-sender (get organizer circle-data))
          (map-set circles
            { circle-id: circle-id }
            (merge circle-data { is-active: false })
          )
          true
        )
        true
      )
      
      (ok true)
    )
    ERR-NOT-MEMBER
  )
)

(define-read-only (get-member-list (circle-id uint))
  (ok (list tx-sender))
)

(define-read-only (get-circle-stats (circle-id uint))
  (match (get-circle circle-id)
    circle-data
    (ok {
      circle-id: circle-id,
      name: (get name circle-data),
      organizer: (get organizer circle-data),
      contribution-amount: (get contribution-amount circle-data),
      current-members: (get current-members circle-data),
      max-members: (get max-members circle-data),
      current-cycle: (get-current-cycle circle-id),
      total-cycles: (get total-cycles circle-data),
      is-active: (get is-active circle-data),
      balance: (get-circle-balance circle-id)
    })
    ERR-CIRCLE-NOT-FOUND
  )
)

