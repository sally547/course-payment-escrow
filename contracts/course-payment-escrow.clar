;; --------------------------------------------
;; Course Payment Escrow Smart Contract
;; Manages secure payments for online courses
;; --------------------------------------------

;; Constants
(define-constant CONTRACT_ADMIN tx-sender)
(define-constant ESCROW_EXPIRATION u1008)  ;; ~7 days assuming 10-minute block times

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_ESCROW_NOT_EXIST (err u301))
(define-constant ERR_ALREADY_PROCESSED (err u302))
(define-constant ERR_PAYMENT_FAILURE (err u303))
(define-constant ERR_INVALID_ID (err u304))
(define-constant ERR_INVALID_AMOUNT (err u305))
(define-constant ERR_INVALID_INSTRUCTOR (err u306))
(define-constant ERR_ESCROW_EXPIRED (err u307))

;; Escrow storage
(define-map CourseEscrowLedger
  { escrow-id: uint }
  {
    learner: principal,
    instructor: principal,
    deposit: uint,
    escrow-status: (string-ascii 10),
    created-at: uint,
    expires-at: uint,
    completed: bool,
    feedback: (string-ascii 100)
  }
)

;; Global variables
(define-data-var escrow-counter uint u0)

;; Private helpers
(define-private (is-valid-instructor (instructor principal))
  (and 
    (not (is-eq instructor tx-sender))
    (not (is-eq instructor (as-contract tx-sender)))
  )
)

(define-private (is-valid-escrow-id (escrow-id uint))
  (<= escrow-id (var-get escrow-counter))
)

(define-private (is-escrow-expired (expires-at uint))
  (>= stacks-block-height expires-at)
)

;; Public Functions

;; Create a new escrow for a course transaction
(define-public (initiate-escrow (instructor principal) (deposit uint))
  (let
    ((escrow-id (+ (var-get escrow-counter) u1))
     (expires-at (+ stacks-block-height ESCROW_EXPIRATION)))
    (asserts! (> deposit u0) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-instructor instructor) ERR_INVALID_INSTRUCTOR)
    (match (stx-transfer? deposit tx-sender (as-contract tx-sender))
      success
        (begin
          (map-set CourseEscrowLedger
            { escrow-id: escrow-id }
            {
              learner: tx-sender,
              instructor: instructor,
              deposit: deposit,
              escrow-status: "locked",
              created-at: stacks-block-height,
              expires-at: expires-at,
              completed: false,
              feedback: ""
            }
          )
          (var-set escrow-counter escrow-id)
          (print {event: "escrow_initialized", escrow-id: escrow-id, learner: tx-sender, instructor: instructor, deposit: deposit})
          (ok escrow-id)
        )
      error ERR_PAYMENT_FAILURE
    )
  )
)

;; Release funds to the instructor when course is completed
(define-public (finalize-payment (escrow-id uint))
  (let
    ((escrow (unwrap! (map-get? CourseEscrowLedger { escrow-id: escrow-id }) ERR_ESCROW_NOT_EXIST)))
    (asserts! (is-valid-escrow-id escrow-id) ERR_INVALID_ID)
    (asserts! (or (is-eq tx-sender CONTRACT_ADMIN) (is-eq tx-sender (get learner escrow))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get escrow-status escrow) "locked") ERR_ALREADY_PROCESSED)
    (asserts! (not (is-escrow-expired (get expires-at escrow))) ERR_ESCROW_EXPIRED)
    (match (as-contract (stx-transfer? (get deposit escrow) tx-sender (get instructor escrow)))
      success 
        (begin
          (map-set CourseEscrowLedger
            { escrow-id: escrow-id }
            (merge escrow { escrow-status: "released" })
          )
          (print {event: "payment_transferred", escrow-id: escrow-id, instructor: (get instructor escrow), deposit: (get deposit escrow)})
          (ok true)
        )
      error ERR_PAYMENT_FAILURE
    )
  )
)

;; Refund learner in case of disputes or expiration
(define-public (reimburse-learner (escrow-id uint))
  (let
    ((escrow (unwrap! (map-get? CourseEscrowLedger { escrow-id: escrow-id }) ERR_ESCROW_NOT_EXIST)))
    (asserts! (is-valid-escrow-id escrow-id) ERR_INVALID_ID)
    (asserts! (or (is-eq tx-sender CONTRACT_ADMIN) (is-escrow-expired (get expires-at escrow))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get escrow-status escrow) "locked") ERR_ALREADY_PROCESSED)
    (match (as-contract (stx-transfer? (get deposit escrow) tx-sender (get learner escrow)))
      success 
        (begin
          (map-set CourseEscrowLedger
            { escrow-id: escrow-id }
            (merge escrow { escrow-status: "refunded" })
          )
          (print {event: "learner_refunded", escrow-id: escrow-id, learner: (get learner escrow), deposit: (get deposit escrow)})
          (ok true)
        )
      error ERR_PAYMENT_FAILURE
    )
  )
)

;; Mark the course as completed
(define-public (confirm-course-completion (escrow-id uint))
  (let
    ((escrow (unwrap! (map-get? CourseEscrowLedger { escrow-id: escrow-id }) ERR_ESCROW_NOT_EXIST)))
    (asserts! (is-valid-escrow-id escrow-id) ERR_INVALID_ID)
    (asserts! (is-eq tx-sender (get instructor escrow)) ERR_UNAUTHORIZED)
    (asserts! (not (is-escrow-expired (get expires-at escrow))) ERR_ESCROW_EXPIRED)
    (map-set CourseEscrowLedger
      { escrow-id: escrow-id }
      (merge escrow { completed: true })
    )
    (print {event: "course_marked_completed", escrow-id: escrow-id, learner: (get learner escrow)})
    (ok true)
  )
)

;; Submit a course review
(define-public (submit-review (escrow-id uint) (feedback (string-ascii 100)))
  (let
    ((escrow (unwrap! (map-get? CourseEscrowLedger { escrow-id: escrow-id }) ERR_ESCROW_NOT_EXIST)))
    (asserts! (is-valid-escrow-id escrow-id) ERR_INVALID_ID)
    (asserts! (is-eq tx-sender (get learner escrow)) ERR_UNAUTHORIZED)
    (map-set CourseEscrowLedger
      { escrow-id: escrow-id }
      (merge escrow { feedback: feedback })
    )
    (print {event: "review_added", escrow-id: escrow-id, learner: (get learner escrow), feedback: feedback})
    (ok true)
  )
)

;; Read Functions

;; Retrieve escrow details
(define-read-only (fetch-escrow-info (escrow-id uint))
  (match (map-get? CourseEscrowLedger { escrow-id: escrow-id })
    escrow (ok escrow)
    ERR_ESCROW_NOT_EXIST
  )
)

;; Get the latest escrow ID
(define-read-only (fetch-latest-escrow-id)
  (ok (var-get escrow-counter))
)