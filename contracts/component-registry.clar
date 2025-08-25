;; Component Registry Contract
;; Manages aerospace component registration and tracking

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-COMPONENT-EXISTS (err u101))
(define-constant ERR-COMPONENT-NOT-FOUND (err u102))
(define-constant ERR-INVALID-INPUT (err u103))

;; Data Variables
(define-data-var next-component-id uint u1)

;; Data Maps
(define-map components
  { component-id: uint }
  {
    serial-number: (string-ascii 50),
    part-number: (string-ascii 50),
    manufacturer: principal,
    manufacture-date: uint,
    material-type: (string-ascii 30),
    weight: uint,
    dimensions: (string-ascii 100),
    status: (string-ascii 20),
    current-owner: principal,
    created-at: uint
  }
)

(define-map component-by-serial
  { serial-number: (string-ascii 50) }
  { component-id: uint }
)

(define-map authorized-manufacturers
  { manufacturer: principal }
  { authorized: bool, authorized-at: uint }
)

;; Authorization Functions
(define-public (authorize-manufacturer (manufacturer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-manufacturers
      { manufacturer: manufacturer }
      { authorized: true, authorized-at: block-height }
    ))
  )
)

(define-public (revoke-manufacturer (manufacturer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-manufacturers
      { manufacturer: manufacturer }
      { authorized: false, authorized-at: block-height }
    ))
  )
)

;; Component Registration
(define-public (register-component
  (serial-number (string-ascii 50))
  (part-number (string-ascii 50))
  (material-type (string-ascii 30))
  (weight uint)
  (dimensions (string-ascii 100))
)
  (let
    (
      (component-id (var-get next-component-id))
      (manufacturer-auth (map-get? authorized-manufacturers { manufacturer: tx-sender }))
    )
    (asserts! (is-some manufacturer-auth) ERR-NOT-AUTHORIZED)
    (asserts! (get authorized (unwrap-panic manufacturer-auth)) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? component-by-serial { serial-number: serial-number })) ERR-COMPONENT-EXISTS)
    (asserts! (> (len serial-number) u0) ERR-INVALID-INPUT)
    (asserts! (> (len part-number) u0) ERR-INVALID-INPUT)
    (asserts! (> weight u0) ERR-INVALID-INPUT)

    (map-set components
      { component-id: component-id }
      {
        serial-number: serial-number,
        part-number: part-number,
        manufacturer: tx-sender,
        manufacture-date: block-height,
        material-type: material-type,
        weight: weight,
        dimensions: dimensions,
        status: "manufactured",
        current-owner: tx-sender,
        created-at: block-height
      }
    )

    (map-set component-by-serial
      { serial-number: serial-number }
      { component-id: component-id }
    )

    (var-set next-component-id (+ component-id u1))
    (ok component-id)
  )
)

;; Component Transfer
(define-public (transfer-component (component-id uint) (new-owner principal))
  (let
    (
      (component (map-get? components { component-id: component-id }))
    )
    (asserts! (is-some component) ERR-COMPONENT-NOT-FOUND)
    (asserts! (is-eq tx-sender (get current-owner (unwrap-panic component))) ERR-NOT-AUTHORIZED)

    (ok (map-set components
      { component-id: component-id }
      (merge (unwrap-panic component) { current-owner: new-owner })
    ))
  )
)

;; Component Status Update
(define-public (update-component-status (component-id uint) (new-status (string-ascii 20)))
  (let
    (
      (component (map-get? components { component-id: component-id }))
    )
    (asserts! (is-some component) ERR-COMPONENT-NOT-FOUND)
    (asserts! (is-eq tx-sender (get current-owner (unwrap-panic component))) ERR-NOT-AUTHORIZED)
    (asserts! (> (len new-status) u0) ERR-INVALID-INPUT)

    (ok (map-set components
      { component-id: component-id }
      (merge (unwrap-panic component) { status: new-status })
    ))
  )
)

;; Read-only Functions
(define-read-only (get-component (component-id uint))
  (map-get? components { component-id: component-id })
)

(define-read-only (get-component-by-serial (serial-number (string-ascii 50)))
  (match (map-get? component-by-serial { serial-number: serial-number })
    component-ref (map-get? components { component-id: (get component-id component-ref) })
    none
  )
)

(define-read-only (is-authorized-manufacturer (manufacturer principal))
  (match (map-get? authorized-manufacturers { manufacturer: manufacturer })
    auth-info (get authorized auth-info)
    false
  )
)

(define-read-only (get-next-component-id)
  (var-get next-component-id)
)
