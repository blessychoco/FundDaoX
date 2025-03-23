;; FundDaoX Platform Smart Contract
 
;; Error Constants
(define-constant PLATFORM-ADMIN tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-FUNDS-SHORTAGE (err u101))
(define-constant ERR-VENTURE-NOT-FOUND (err u102))
(define-constant ERR-FUNDING-CLOSED (err u103))
(define-constant ERR-GOAL-ALREADY-APPROVED (err u104))
(define-constant ERR-INVALID-GOAL-INDEX (err u105))
(define-constant ERR-NO-WITHDRAWAL-ELIGIBLE (err u106))
(define-constant ERR-ALREADY-WITHDRAWN (err u107))
(define-constant ERR-VENTURE-SUCCESSFUL (err u108))
(define-constant ERR-INVALID-PARAMS (err u109))
(define-constant ERR-NOT-ALL-GOALS-COMPLETE (err u110))

;; Venture structure
(define-map ventures
  { venture-id: uint }
  {
    founder: principal,
    name: (string-utf8 100),
    summary: (string-utf8 500),
    funding-goal: uint,
    collected-amount: uint,
    end-date: uint,
    is-open: bool,
    is-finalized: bool,
    goals: (list 5 { summary: (string-utf8 200), funds: uint, completed: bool })
  }
)

;; Backers tracking with withdrawal status
(define-map backers 
  { venture-id: uint, backer: principal } 
  { 
    amount: uint,
    withdrawn: bool 
  }
)

;; Unique venture ID counter
(define-data-var next-venture-id uint u0)

;; Helper function to check if all goals are approved
(define-read-only (all-goals-completed? (goals (list 5 { summary: (string-utf8 200), funds: uint, completed: bool })))
  (is-eq (len (filter is-goal-completed goals)) (len goals))
)

;; Helper function to check if a goal is completed
(define-read-only (is-goal-completed (goal { summary: (string-utf8 200), funds: uint, completed: bool }))
  (get completed goal)
)

;; Create a new funding venture
(define-public (create-venture 
  (name (string-utf8 100))
  (summary (string-utf8 500))
  (funding-goal uint)
  (end-date uint)
  (goals (list 5 { summary: (string-utf8 200), funds: uint }))
)
  (let 
    (
      (venture-id (var-get next-venture-id))
      (total-goals-funds (fold + (map get-goal-funds goals) u0))
    )
    ;; Validate inputs
    (asserts! (> (len name) u0) ERR-INVALID-PARAMS)
    (asserts! (> (len summary) u0) ERR-INVALID-PARAMS)
    (asserts! (> funding-goal u0) ERR-INVALID-PARAMS)
    (asserts! (> end-date block-height) ERR-INVALID-PARAMS)
    (asserts! (>= funding-goal total-goals-funds) ERR-FUNDS-SHORTAGE)
    
    ;; Create venture map entry
    (map-set ventures 
      { venture-id: venture-id }
      {
        founder: tx-sender,
        name: name,
        summary: summary,
        funding-goal: funding-goal,
        collected-amount: u0,
        end-date: end-date,
        is-open: true,
        is-finalized: false,
        goals: (map prepare-goal goals)
      }
    )
    
    ;; Increment venture ID
    (var-set next-venture-id (+ venture-id u1))
    
    ;; Return venture ID
    (ok venture-id)
  )
)

;; Helper function to get goal funds
(define-read-only (get-goal-funds (goal { summary: (string-utf8 200), funds: uint }))
  (get funds goal)
)

;; Helper function to prepare goal
(define-read-only (prepare-goal (goal { summary: (string-utf8 200), funds: uint }))
  { summary: (get summary goal), funds: (get funds goal), completed: false }
)

;; Get goal by index
(define-private (get-goal-by-index 
  (venture-goals (list 5 { summary: (string-utf8 200), funds: uint, completed: bool })) 
  (goal-index uint)
)
  (element-at venture-goals goal-index)
)

;; Update goal in list
(define-private (update-goal-list 
  (goals (list 5 { summary: (string-utf8 200), funds: uint, completed: bool })) 
  (goal-index uint)
  (updated-goal { summary: (string-utf8 200), funds: uint, completed: bool })
)
  (let
    (
      (prefix (unwrap! (slice? goals u0 goal-index) goals))
      (suffix (unwrap! (slice? goals (+ goal-index u1) (len goals)) goals))
    )
    (unwrap-panic 
      (as-max-len? 
        (concat
          prefix
          (unwrap-panic 
            (as-max-len? 
              (concat 
                (list updated-goal)
                suffix
              )
              u5
            )
          )
        )
        u5
      )
    )
  )
)

;; Check if venture is eligible for withdrawals
(define-read-only (is-withdrawal-eligible (venture-id uint))
  (match (map-get? ventures { venture-id: venture-id })
    venture (and 
      (>= block-height (get end-date venture))
      (< (get collected-amount venture) (get funding-goal venture))
      (get is-open venture)
    )
    false
  )
)

