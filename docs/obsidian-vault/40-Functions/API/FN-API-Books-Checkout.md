---
tags: [type/function]
area: api
status: in-progress
version: 0.3.0
date: 2026-05-20
feature: [[FEAT-Checkout]]
---

# FN-API-Books-Checkout

## 1. Purpose
สร้าง loan record — backing สำหรับ [[FN-Web-Librarian-CheckoutFlow]]

## 2. Trigger
- `POST /api/loans`

## 3. Inputs

Body:
```json
{
  "member_id": "uuid",
  "book_barcode": "string",
  "override_max_loans": false
}
```

## 4. Behavior / Flow
1. Validate JWT → Librarian role
2. Load Member by id → status: active (else 422)
3. Load Book by barcode → status: available (else 409 with current loan)
4. Check active loans < 5 (unless `override_max_loans: true`)
5. **Optimistic lock**: SELECT FOR UPDATE on Book, recheck status
6. INSERT Loan {member_id, book_id, checkout_at=now, due_at=now+14d, status: active}
7. UPDATE Book.status = on_loan
8. UPDATE Member.active_loans_count += 1
9. Audit log entry
10. Return Loan JSON

## 5. Outputs / Result

Success 201:
```json
{
  "id": "uuid",
  "member_id": "uuid",
  "book_id": "uuid",
  "checkout_at": "2026-05-20T10:30:00Z",
  "due_at": "2026-06-03T10:30:00Z",
  "status": "active"
}
```

Errors:
- 401: not authenticated
- 403: not Librarian role
- 404: member or book not found
- 409: book already on loan (body includes current borrower for librarian to message)
- 422 (BUSINESS_RULE): book status lost / member status inactive / max loans reached + no override

## 6. Side effects
- Database: Loan inserted; Book.status updated; Member.active_loans_count updated
- Audit log: `{user, action: "loan:create", member_id, book_id, override, timestamp}`

## 7. Auth / RBAC
- Role: Librarian
- Permission: `loans:write`

## 8. Performance
- Target: p95 < 1s (includes optimistic lock retry)
- Transaction: serializable for the SELECT FOR UPDATE

## 9. Edge cases
- Concurrent checkout (race): optimistic lock catches → 409
- Database transaction failure → 500, no partial write (transaction rollback)

## 10. Test scenarios
- [[TP-Checkout]]

## 11. Implementation
- Plan: [[2026-05-20-1015-checkout-api]] (in-progress)
- Files:
  - `api/Controllers/LoansController.cs`
  - `api/Services/LoanService.cs`
  - `api/Repositories/LoanRepository.cs`
  - `api/Repositories/BookRepository.cs` (SELECT FOR UPDATE)
  - `api/Tests/LoanServiceTests.cs`
  - `api/Tests/Integration/LoanCheckoutTests.cs`
