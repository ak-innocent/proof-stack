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