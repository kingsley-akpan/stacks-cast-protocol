;; StacksCast Protocol - Decentralized Bitcoin Price Prediction Market
;;
;; Title: StacksCast - Advanced Bitcoin Price Prediction Protocol
;;
;; Summary: A cutting-edge decentralized prediction market built on Stacks Layer 2,
;;          enabling trustless Bitcoin price forecasting with automated settlements,
;;          proportional reward distribution, and community-driven oracle validation.
;;
;; Description:
;;   StacksCast revolutionizes Bitcoin price prediction by creating a transparent,
;;   fair, and profitable DeFi ecosystem. Leveraging the security of Bitcoin through
;;   Stacks Layer 2, our protocol empowers users to stake STX tokens on Bitcoin's
;;   price movements within precisely defined time windows.
;;
;;   The protocol features sophisticated oracle integration, anti-manipulation
;;   mechanisms, and proportional reward distribution ensuring fair compensation
;;   based on stake size and market participation. Built with institutional-grade
;;   security and retail-friendly accessibility, StacksCast bridges traditional
;;   prediction markets with Bitcoin's decentralized ethos.
;;
;;   Core innovations include dynamic fee structures, comprehensive user analytics,
;;   configurable market parameters, and seamless Bitcoin Layer 2 integration that
;;   maintains Bitcoin's security guarantees while enabling advanced financial
;;   primitives previously impossible on Bitcoin's base layer.
;;
;; Key Features:
;;   - Trustless oracle integration for precise price settlement
;;   - Proportional reward pools with transparent distribution
;;   - Dynamic market creation with flexible time windows
;;   - Advanced anti-manipulation and security safeguards
;;   - Real-time performance tracking and user analytics
;;   - Comprehensive administrative controls
;;   - Full Stacks Layer 2 compatibility with Bitcoin security inheritance
;;

;; SYSTEM CONSTANTS

;; Administrative & Security Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-FEE-PERCENTAGE u10) ;; 10% maximum platform fee cap
(define-constant MIN-MARKET-DURATION u10) ;; Minimum 10 blocks for market duration
(define-constant MAX-STAKE-LIMIT u100000000) ;; Maximum 100 STX stake limit

;; Comprehensive Error Code System
(define-constant ERR-OWNER-ONLY (err u100)) ;; Unauthorized administrative access
(define-constant ERR-NOT-FOUND (err u101)) ;; Resource not found in storage
(define-constant ERR-INVALID-PREDICTION (err u102)) ;; Invalid prediction parameters
(define-constant ERR-MARKET-CLOSED (err u103)) ;; Market outside active window
(define-constant ERR-ALREADY-CLAIMED (err u104)) ;; Reward already claimed
(define-constant ERR-INSUFFICIENT-BALANCE (err u105)) ;; Insufficient STX balance
(define-constant ERR-INVALID-PARAMETER (err u106)) ;; Invalid function parameter
(define-constant ERR-MARKET-NOT-RESOLVED (err u107)) ;; Market resolution pending
(define-constant ERR-UNAUTHORIZED-ORACLE (err u108)) ;; Oracle authorization failure

;; PLATFORM CONFIGURATION

;; Core Platform Variables
(define-data-var oracle-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var minimum-stake uint u1000000) ;; 1 STX minimum (1,000,000 microSTX)
(define-data-var platform-fee-rate uint u250) ;; 2.5% platform fee (250 basis points)
(define-data-var market-counter uint u0) ;; Global market identifier counter
(define-data-var total-volume uint u0) ;; Cumulative platform volume tracking

;; DATA STRUCTURES & STORAGE

;; Primary Market Data Structure
(define-map markets
  uint ;; market-id (primary key)
  {
    start-price: uint, ;; Bitcoin price at market initialization (satoshis)
    end-price: uint, ;; Bitcoin price at market resolution (satoshis)
    total-up-stake: uint, ;; Total STX staked on bullish predictions
    total-down-stake: uint, ;; Total STX staked on bearish predictions
    start-block: uint, ;; Block height when predictions begin
    end-block: uint, ;; Block height when prediction window closes
    resolution-block: uint, ;; Block height of market resolution
    resolved: bool, ;; Market resolution status flag
    creator: principal, ;; Market creator principal address
  }
)

;; User Prediction Tracking System
(define-map user-predictions
  {
    market-id: uint,
    user: principal,
  }
  ;; composite key
  {
    prediction-type: (string-ascii 4), ;; "up" or "down" direction
    stake-amount: uint, ;; STX amount staked (microSTX)
    timestamp: uint, ;; Block height of prediction submission
    claimed: bool, ;; Reward claim status flag
    potential-payout: uint, ;; Calculated potential winnings
  }
)

;; Comprehensive User Statistics
(define-map user-stats
  principal ;; user address
  {
    total-predictions: uint, ;; Lifetime prediction count
    total-staked: uint, ;; Cumulative STX staked amount
    total-won: uint, ;; Total winnings claimed
    win-rate: uint, ;; Win percentage (basis points)
  }
)

;; MARKET LIFECYCLE MANAGEMENT

;; Create New Bitcoin Price Prediction Market
;; Initializes a new prediction market with comprehensive validation and configuration
(define-public (create-market
    (start-price uint)
    (start-block uint)
    (end-block uint)
  )
  (let (
      (new-market-id (var-get market-counter))
      (current-block stacks-block-height)
    )
    ;; Administrative authorization check
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    ;; Comprehensive parameter validation
    (asserts! (> end-block start-block) ERR-INVALID-PARAMETER)
    (asserts! (> start-price u0) ERR-INVALID-PARAMETER)
    (asserts! (>= start-block current-block) ERR-INVALID-PARAMETER)
    (asserts! (>= (- end-block start-block) MIN-MARKET-DURATION)
      ERR-INVALID-PARAMETER
    )
    ;; Initialize market with complete data structure
    (map-set markets new-market-id {
      start-price: start-price,
      end-price: u0,
      total-up-stake: u0,
      total-down-stake: u0,
      start-block: start-block,
      end-block: end-block,
      resolution-block: u0,
      resolved: false,
      creator: tx-sender,
    })
    ;; Increment global counter for next market
    (var-set market-counter (+ new-market-id u1))
    (ok new-market-id)
  )
)

;; Oracle-Driven Market Resolution System
;; Authorized oracle resolves market with final Bitcoin price for automated settlement
(define-public (resolve-market
    (market-id uint)
    (final-price uint)
  )
  (let (
      (market-data (unwrap! (map-get? markets market-id) ERR-NOT-FOUND))
      (current-block stacks-block-height)
    )
    ;; Oracle authorization and timing validation
    (asserts! (is-eq tx-sender (var-get oracle-address)) ERR-UNAUTHORIZED-ORACLE)
    (asserts! (>= current-block (get end-block market-data)) ERR-MARKET-CLOSED)
    (asserts! (not (get resolved market-data)) ERR-MARKET-CLOSED)
    (asserts! (> final-price u0) ERR-INVALID-PARAMETER)
    ;; Update market with comprehensive resolution data
    (map-set markets market-id
      (merge market-data {
        end-price: final-price,
        resolution-block: current-block,
        resolved: true,
      })
    )
    (ok true)
  )
)

;; USER PARTICIPATION & STAKING

;; Submit Price Prediction with STX Stake
;; Enables users to stake STX tokens on Bitcoin price direction within active markets
(define-public (make-prediction
    (market-id uint)
    (prediction-direction (string-ascii 4))
    (stake-amount uint)
  )
  (let (
      (market-data (unwrap! (map-get? markets market-id) ERR-NOT-FOUND))
      (current-block stacks-block-height)
      (user-balance (stx-get-balance tx-sender))
    )
    ;; Market timing and parameter validation
    (asserts!
      (and
        (>= current-block (get start-block market-data))
        (< current-block (get end-block market-data))
      )
      ERR-MARKET-CLOSED
    )
    (asserts!
      (or (is-eq prediction-direction "up") (is-eq prediction-direction "down"))
      ERR-INVALID-PREDICTION
    )
    (asserts! (>= stake-amount (var-get minimum-stake)) ERR-INVALID-PARAMETER)
    (asserts! (<= stake-amount MAX-STAKE-LIMIT) ERR-INVALID-PARAMETER)
    (asserts! (<= stake-amount user-balance) ERR-INSUFFICIENT-BALANCE)
    ;; Execute STX transfer to contract for secure escrow
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    ;; Record comprehensive user prediction data
    (map-set user-predictions {
      market-id: market-id,
      user: tx-sender,
    } {
      prediction-type: prediction-direction,
      stake-amount: stake-amount,
      timestamp: current-block,
      claimed: false,
      potential-payout: u0,
    })
    ;; Update market stake totals for accurate pool calculation
    (map-set markets market-id
      (merge market-data {
        total-up-stake: (if (is-eq prediction-direction "up")
          (+ (get total-up-stake market-data) stake-amount)
          (get total-up-stake market-data)
        ),
        total-down-stake: (if (is-eq prediction-direction "down")
          (+ (get total-down-stake market-data) stake-amount)
          (get total-down-stake market-data)
        ),
      })
    )
    ;; Update platform volume tracking and user statistics
    (var-set total-volume (+ (var-get total-volume) stake-amount))
    (update-user-stats tx-sender stake-amount)
    (ok true)
  )
)