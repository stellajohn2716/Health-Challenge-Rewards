(define-fungible-token fitness-token)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-invalid-goal (err u103))
(define-constant err-challenge-not-found (err u104))
(define-constant err-challenge-expired (err u105))
(define-constant err-already-completed (err u106))
(define-constant err-insufficient-steps (err u107))
(define-constant err-unauthorized-oracle (err u108))

(define-constant err-badge-not-found (err u109))
(define-constant err-badge-already-owned (err u110))

(define-constant err-bonus-claimed (err u111))
(define-constant err-bonus-unavailable (err u112))

(define-constant speed-bonus-cap-bps u2000)
(define-constant bps-denom u10000)

(define-data-var badge-counter uint u0)

(define-data-var token-name (string-ascii 32) "FitnessToken")
(define-data-var token-symbol (string-ascii 10) "FIT")
(define-data-var token-decimals uint u6)
(define-data-var challenge-counter uint u0)

(define-map users principal {
  registered: bool,
  total-tokens: uint,
  completed-challenges: uint
})

(define-map fitness-oracles principal bool)

(define-map challenges uint {
  creator: principal,
  step-goal: uint,
  reward-amount: uint,
  duration-blocks: uint,
  start-block: uint,
  active: bool
})

(define-map user-challenges {user: principal, challenge-id: uint} {
  steps-completed: uint,
  completed: bool,
  claim-block: uint
})

(define-read-only (get-balance (account principal))
  (ft-get-balance fitness-token account)
)

(define-read-only (get-total-supply)
  (ft-get-supply fitness-token)
)

(define-read-only (get-token-uri)
  (ok none)
)

(define-read-only (get-user-info (user principal))
  (map-get? users user)
)

(define-read-only (get-challenge-info (challenge-id uint))
  (map-get? challenges challenge-id)
)

(define-read-only (get-user-challenge-progress (user principal) (challenge-id uint))
  (map-get? user-challenges {user: user, challenge-id: challenge-id})
)

(define-read-only (is-oracle-authorized (oracle principal))
  (default-to false (map-get? fitness-oracles oracle))
)

(define-read-only (is-challenge-active (challenge-id uint))
  (match (map-get? challenges challenge-id)
    challenge-data (let
      ((current-block stacks-block-height)
       (end-block (+ (get start-block challenge-data) (get duration-blocks challenge-data))))
      (and (get active challenge-data) (< current-block end-block)))
    false
  )
)

(define-public (register-user)
  (let ((caller tx-sender))
    (asserts! (is-none (map-get? users caller)) err-already-registered)
    (map-set users caller {
      registered: true,
      total-tokens: u0,
      completed-challenges: u0
    })
    (ok true)
  )
)

(define-public (add-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set fitness-oracles oracle true)
    (ok true)
  )
)

(define-public (remove-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-delete fitness-oracles oracle)
    (ok true)
  )
)

(define-public (create-challenge (step-goal uint) (reward-amount uint) (duration-blocks uint))
  (let
    ((caller tx-sender)
     (new-challenge-id (+ (var-get challenge-counter) u1))
     (current-block stacks-block-height))
    (asserts! (> step-goal u0) err-invalid-goal)
    (asserts! (> reward-amount u0) err-invalid-goal)
    (asserts! (> duration-blocks u0) err-invalid-goal)
    (asserts! (is-some (map-get? users caller)) err-not-registered)
    
    (try! (ft-mint? fitness-token reward-amount caller))
    (map-set challenges new-challenge-id {
      creator: caller,
      step-goal: step-goal,
      reward-amount: reward-amount,
      duration-blocks: duration-blocks,
      start-block: current-block,
      active: true
    })
    (var-set challenge-counter new-challenge-id)
    (ok new-challenge-id)
  )
)

(define-public (join-challenge (challenge-id uint))
  (let ((caller tx-sender))
    (asserts! (is-some (map-get? users caller)) err-not-registered)
    (asserts! (is-some (map-get? challenges challenge-id)) err-challenge-not-found)
    (asserts! (is-challenge-active challenge-id) err-challenge-expired)
    (asserts! (is-none (map-get? user-challenges {user: caller, challenge-id: challenge-id})) err-already-completed)
    
    (map-set user-challenges {user: caller, challenge-id: challenge-id} {
      steps-completed: u0,
      completed: false,
      claim-block: u0
    })
    (ok true)
  )
)

(define-public (submit-steps (user principal) (challenge-id uint) (steps uint))
  (let ((caller tx-sender))
    (asserts! (is-oracle-authorized caller) err-unauthorized-oracle)
    (asserts! (is-some (map-get? users user)) err-not-registered)
    (asserts! (is-some (map-get? challenges challenge-id)) err-challenge-not-found)
    (asserts! (is-challenge-active challenge-id) err-challenge-expired)
    
    (match (map-get? user-challenges {user: user, challenge-id: challenge-id})
      current-progress (begin
        (asserts! (not (get completed current-progress)) err-already-completed)
        (map-set user-challenges {user: user, challenge-id: challenge-id} 
          (merge current-progress {steps-completed: (+ (get steps-completed current-progress) steps)}))
        (ok true))
      err-challenge-not-found
    )
  )
)

(define-public (claim-reward (challenge-id uint))
  (let 
    ((caller tx-sender)
     (current-block stacks-block-height))
    (asserts! (is-some (map-get? users caller)) err-not-registered)
    
    (match (map-get? challenges challenge-id)
      challenge-data 
        (match (map-get? user-challenges {user: caller, challenge-id: challenge-id})
          user-progress (begin
            (asserts! (not (get completed user-progress)) err-already-completed)
            (asserts! (>= (get steps-completed user-progress) (get step-goal challenge-data)) err-insufficient-steps)
            
            (try! (ft-transfer? fitness-token (get reward-amount challenge-data) (get creator challenge-data) caller))
            (map-set user-challenges {user: caller, challenge-id: challenge-id}
              (merge user-progress {completed: true, claim-block: current-block}))
            
            (match (map-get? users caller)
              user-data (map-set users caller 
                (merge user-data {
                  total-tokens: (+ (get total-tokens user-data) (get reward-amount challenge-data)),
                  completed-challenges: (+ (get completed-challenges user-data) u1)
                }))
              false)
            (ok true))
          err-challenge-not-found)
      err-challenge-not-found
    )
  )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err u4))
    (ft-transfer? fitness-token amount sender recipient)
  )
)


(define-map badges uint {
  name: (string-ascii 32),
  description: (string-ascii 128),
  requirement: uint,
  badge-type: (string-ascii 16)
})

(define-map user-badges {user: principal, badge-id: uint} bool)

(define-read-only (get-badge-info (badge-id uint))
  (map-get? badges badge-id)
)

(define-read-only (user-has-badge (user principal) (badge-id uint))
  (default-to false (map-get? user-badges {user: user, badge-id: badge-id}))
)

(define-read-only (get-user-badge-count (user principal))
  (let ((total-badges (var-get badge-counter)))
    (fold check-user-badge 
      (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) 
      {user: user, count: u0, max: total-badges})
  )
)

(define-private (check-user-badge (badge-id uint) (acc {user: principal, count: uint, max: uint}))
  (if (and (<= badge-id (get max acc)) (user-has-badge (get user acc) badge-id))
    (merge acc {count: (+ (get count acc) u1)})
    acc
  )
)

(define-public (create-badge (name (string-ascii 32)) (description (string-ascii 128)) 
                           (requirement uint) (badge-type (string-ascii 16)))
  (let ((new-badge-id (+ (var-get badge-counter) u1)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set badges new-badge-id {
      name: name,
      description: description,
      requirement: requirement,
      badge-type: badge-type
    })
    (var-set badge-counter new-badge-id)
    (ok new-badge-id)
  )
)

(define-public (award-badge (user principal) (badge-id uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (map-get? badges badge-id)) err-badge-not-found)
    (asserts! (not (user-has-badge user badge-id)) err-badge-already-owned)
    (map-set user-badges {user: user, badge-id: badge-id} true)
    (ok true)
  )
)


(define-map speed-bonus-claimed {user: principal, challenge-id: uint} bool)

(define-read-only (has-claimed-speed-bonus (user principal) (challenge-id uint))
  (default-to false (map-get? speed-bonus-claimed {user: user, challenge-id: challenge-id}))
)

(define-public (claim-speed-bonus (challenge-id uint))
  (let ((caller tx-sender))
    (asserts! (not (has-claimed-speed-bonus caller challenge-id)) err-bonus-claimed)
    (match (map-get? user-challenges {user: caller, challenge-id: challenge-id})
      user-progress
        (begin
          (asserts! (get completed user-progress) err-bonus-unavailable)
          (match (map-get? challenges challenge-id)
            challenge-data
              (let
                ((end-block (+ (get start-block challenge-data) (get duration-blocks challenge-data)))
                 (claim-blk (get claim-block user-progress))
                 (remaining (if (< claim-blk end-block) (- end-block claim-blk) u0))
                 (reward (get reward-amount challenge-data))
                 (duration (get duration-blocks challenge-data))
                 (base-bonus (if (> duration u0) (/ (* reward remaining) duration) u0))
                 (max-bonus (/ (* reward speed-bonus-cap-bps) bps-denom))
                 (final-bonus (if (> base-bonus max-bonus) max-bonus base-bonus)))
                (begin
                  (asserts! (> final-bonus u0) err-bonus-unavailable)
                  (try! (ft-mint? fitness-token final-bonus caller))
                  (map-set speed-bonus-claimed {user: caller, challenge-id: challenge-id} true)
                  (ok final-bonus)))
            err-challenge-not-found))
      err-challenge-not-found))
)