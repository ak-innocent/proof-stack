;; Title: ProofStack - Decentralized Contribution Recognition System
;;
;; Summary: A trustless protocol for tracking, verifying, and rewarding collaborative 
;; contributions on Bitcoin's Layer 2, enabling transparent reputation building through 
;; verifiable on-chain proof of work.
;;
;; Description: ProofStack establishes a permissionless framework for communities to 
;; recognize and incentivize meaningful contributions. Contributors submit their work 
;; on-chain, admins verify authenticity and assign merit scores, and the protocol 
;; automatically calculates reputation tiers (Bronze to Platinum) based on cumulative 
;; impact. By anchoring contribution records to Bitcoin's security via Stacks, ProofStack 
;; creates portable, tamper-proof reputation that participants own forever. Perfect for 
;; DAOs, open-source projects, creator collectives, and any community seeking fair, 
;; transparent recognition of member contributions without centralized gatekeepers.

;; Constants and Error Codes

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-VERIFIED (err u102))

;; Contribution tier constants
(define-constant BRONZE u1)
(define-constant SILVER u2)
(define-constant GOLD u3)
(define-constant PLATINUM u4)

;; Tier progression thresholds
(define-constant SILVER-THRESHOLD u100)
(define-constant GOLD-THRESHOLD u250)
(define-constant PLATINUM-THRESHOLD u500)

;; Data Storage

;; Contributor profiles tracking reputation and activity
(define-map Contributors
  principal
  {
    total-score: uint,
    contribution-count: uint,
    tier: uint,
    is-active: bool,
  }
)

;; Individual contribution records with verification status
(define-map Contributions
  uint
  {
    contributor: principal,
    timestamp: uint,
    details: (string-utf8 256),
    score: uint,
    verified: bool,
  }
)

;; Access control for contribution verifiers
(define-map project-admins
  principal
  bool
)

;; Counter for generating unique contribution IDs
(define-data-var contribution-counter uint u0)

;; Administrative Functions

;; Initialize contract and set deployer as first admin
(define-public (initialize)
  (begin
    (map-set project-admins CONTRACT-OWNER true)
    (ok true)
  )
)

;; Grant admin privileges to new verifiers
;; @param admin: Principal address to receive admin rights
(define-public (add-project-admin (admin principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (ok (map-set project-admins admin true))
  )
)

;; Core Contribution Functions

;; Submit a new contribution for verification
;; @param details: UTF-8 description of the contribution (max 256 chars)
;; @returns contribution-id for tracking
(define-public (submit-contribution (details (string-utf8 256)))
  (let (
      (contribution-id (+ (var-get contribution-counter) u1))
      (contributor tx-sender)
    )
    (begin
      (var-set contribution-counter contribution-id)
      (map-set Contributions contribution-id {
        contributor: contributor,
        timestamp: stacks-block-height,
        details: details,
        score: u0,
        verified: false,
      })
      (match (map-get? Contributors contributor)
        prev-profile (map-set Contributors contributor {
          total-score: (get total-score prev-profile),
          contribution-count: (+ (get contribution-count prev-profile) u1),
          tier: (get tier prev-profile),
          is-active: true,
        })
        (map-set Contributors contributor {
          total-score: u0,
          contribution-count: u1,
          tier: BRONZE,
          is-active: true,
        })
      )
      (ok contribution-id)
    )
  )
)

;; Verify contribution authenticity and assign merit score
;; @param contribution-id: ID of contribution to verify
;; @param score: Merit points awarded (influences tier progression)
(define-public (verify-contribution
    (contribution-id uint)
    (score uint)
  )
  (let ((contribution (unwrap! (map-get? Contributions contribution-id) ERR-NOT-FOUND)))
    (begin
      (asserts! (default-to false (map-get? project-admins tx-sender))
        ERR-OWNER-ONLY
      )
      (asserts! (not (get verified contribution)) ERR-ALREADY-VERIFIED)

      ;; Mark contribution as verified with assigned score
      (map-set Contributions contribution-id
        (merge contribution {
          score: score,
          verified: true,
        })
      )

      ;; Update contributor's cumulative reputation
      (match (map-get? Contributors (get contributor contribution))
        prev-profile (begin
          (map-set Contributors (get contributor contribution)
            (merge prev-profile { total-score: (+ (get total-score prev-profile) score) })
          )
          (ok true)
        )
        ERR-NOT-FOUND
      )
    )
  )
)

;; Recalculate and update contributor's tier based on total score
;; @param contributor: Principal whose tier should be updated
(define-public (update-contributor-tier (contributor principal))
  (match (map-get? Contributors contributor)
    profile (let ((total-score (get total-score profile)))
      (begin
        (map-set Contributors contributor
          (merge profile { tier: (if (>= total-score PLATINUM-THRESHOLD)
            PLATINUM
            (if (>= total-score GOLD-THRESHOLD)
              GOLD
              (if (>= total-score SILVER-THRESHOLD)
                SILVER
                BRONZE
              )
            )
          ) }
          ))
        (ok true)
      )
    )
    ERR-NOT-FOUND
  )
)

;; Read-Only Functions

;; Retrieve contribution details by ID
(define-read-only (get-contribution (contribution-id uint))
  (map-get? Contributions contribution-id)
)

;; Get complete contributor profile and reputation data
(define-read-only (get-contributor-profile (contributor principal))
  (map-get? Contributors contributor)
)

;; Query current tier level for a contributor
(define-read-only (get-contributor-tier (contributor principal))
  (match (map-get? Contributors contributor)
    profile (ok (get tier profile))
    ERR-NOT-FOUND
  )
)

;; Check if an address has admin verification privileges
(define-read-only (is-project-admin (address principal))
  (default-to false (map-get? project-admins address))
)
