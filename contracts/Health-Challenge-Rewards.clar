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
