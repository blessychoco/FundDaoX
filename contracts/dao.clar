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

;; Back a venture
(define-public (back-venture (venture-id uint) (stx-transferred uint))
  (let 
    (
      (venture (unwrap! (map-get? ventures { venture-id: venture-id }) ERR-VENTURE-NOT-FOUND))
      (current-backing (default-to { amount: u0, withdrawn: false } 
        (map-get? backers { venture-id: venture-id, backer: tx-sender })))
    )
    ;; Validate inputs
    (asserts! (> venture-id u0) ERR-INVALID-PARAMS)
    (asserts! (> stx-transferred u0) ERR-INVALID-PARAMS)
    
    ;; Validate venture is open and not past end date
    (asserts! (get is-open venture) ERR-FUNDING-CLOSED)
    (asserts! (< block-height (get end-date venture)) ERR-FUNDING-CLOSED)
    
    ;; Update backers
    (map-set backers 
      { venture-id: venture-id, backer: tx-sender }
      { amount: (+ (get amount current-backing) stx-transferred), withdrawn: false }
    )
    
    ;; Update venture collected amount
    (map-set ventures 
      { venture-id: venture-id }
      (merge venture { collected-amount: (+ (get collected-amount venture) stx-transferred) })
    )
    
    (ok true)
  )
)

;; Request withdrawal for a failed venture
(define-public (request-withdrawal (venture-id uint))
  (let
    (
      (venture (unwrap! (map-get? ventures { venture-id: venture-id }) ERR-VENTURE-NOT-FOUND))
      (backing (unwrap! (map-get? backers { venture-id: venture-id, backer: tx-sender }) 
        ERR-NO-WITHDRAWAL-ELIGIBLE))
    )
    ;; Validate input
    (asserts! (> venture-id u0) ERR-INVALID-PARAMS)
    
    ;; Check withdrawal eligibility
    (asserts! (is-withdrawal-eligible venture-id) ERR-VENTURE-SUCCESSFUL)
    (asserts! (not (get withdrawn backing)) ERR-ALREADY-WITHDRAWN)
    
    ;; Process withdrawal
    (try! (stx-transfer? (get amount backing) tx-sender PLATFORM-ADMIN))
    
    ;; Mark backing as withdrawn
    (map-set backers
      { venture-id: venture-id, backer: tx-sender }
      (merge backing { withdrawn: true })
    )
    
    (ok true)
  )
)

;; Close failed venture and enable withdrawals
(define-public (close-failed-venture (venture-id uint))
  (let
    (
      (venture (unwrap! (map-get? ventures { venture-id: venture-id }) ERR-VENTURE-NOT-FOUND))
    )
    ;; Validate input
    (asserts! (> venture-id u0) ERR-INVALID-PARAMS)
    
    ;; Verify venture has failed
    (asserts! (>= block-height (get end-date venture)) ERR-FUNDING-CLOSED)
    (asserts! (< (get collected-amount venture) (get funding-goal venture)) ERR-VENTURE-SUCCESSFUL)
    (asserts! (get is-open venture) ERR-FUNDING-CLOSED)
    
    ;; Update venture status
    (map-set ventures
      { venture-id: venture-id }
      (merge venture { is-open: false })
    )
    
    (ok true)
  )
)

;; Complete goal
(define-public (complete-goal (venture-id uint) (goal-index uint))
  (let 
    (
      (venture (unwrap! (map-get? ventures { venture-id: venture-id }) ERR-VENTURE-NOT-FOUND))
      (goals (get goals venture))
      (goal-opt (get-goal-by-index goals goal-index))
      (goal (unwrap! goal-opt ERR-INVALID-GOAL-INDEX))
    )
    ;; Validate inputs
    (asserts! (> venture-id u0) ERR-INVALID-PARAMS)
    (asserts! (< goal-index (len goals)) ERR-INVALID-PARAMS)
    
    ;; Only venture founder can complete goals
    (asserts! (is-eq tx-sender (get founder venture)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get completed goal)) ERR-GOAL-ALREADY-APPROVED)
    
    ;; Update goal completion
    (map-set ventures 
      { venture-id: venture-id }
      (merge venture { goals: (update-goal-list goals goal-index (merge goal { completed: true })) })
    )
    
    (ok true)
  )
)

;; Finalize venture function
(define-public (finalize-venture (venture-id uint))
  (let
    (
      (venture (unwrap! (map-get? ventures { venture-id: venture-id }) ERR-VENTURE-NOT-FOUND))
    )
    ;; Validate inputs
    (asserts! (> venture-id u0) ERR-INVALID-PARAMS)
    
    ;; Only venture founder can finalize the venture
    (asserts! (is-eq tx-sender (get founder venture)) ERR-NOT-AUTHORIZED)
    
    ;; Check if venture is open
    (asserts! (get is-open venture) ERR-FUNDING-CLOSED)
    
    ;; Check if all goals are completed
    (asserts! (all-goals-completed? (get goals venture)) ERR-NOT-ALL-GOALS-COMPLETE)
    
    ;; Update venture status
    (map-set ventures
      { venture-id: venture-id }
      (merge venture 
        { 
          is-open: false,
          is-finalized: true
        }
      )
    )
    
    (ok true)
  )
)