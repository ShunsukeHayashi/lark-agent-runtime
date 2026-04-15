# auth suggest — Verification Cases

> Canonical test cases for `larc auth suggest`. Each case has a task description,
> expected minimum scopes, and the authority reasoning behind each scope.
>
> Status as of: 2026-04-14
> Scope-map version: 0.2.0

These cases were derived from realistic office-work scenarios that span multiple
Lark surfaces. They serve as regression tests and as evidence that the permission
model is working.

---

## How to re-verify

```bash
larc auth suggest "<task description>"
# check that all expected scopes appear in the output
```

A case is passing if every scope in the Expected column appears in the output.
Extra scopes are a warning (over-permission) but not a failure.

---

## Case 1 — Expense report + approval submission

**Task:** `create expense report and request approval`

**Expected scopes:**
| Scope | Why |
|---|---|
| `base:record:created` | Expense record is stored in Lark Base |
| `approval:instance:write` | Submitting an approval instance requires write authority |

**Authority path:** user — both actions are performed as the person filing the expense.

**Status:** ✅ passing (2 scopes)

---

## Case 2 — Document read + wiki update

**Task:** `read a document and update the wiki page`

**Expected scopes:**
| Scope | Why |
|---|---|
| `docs:doc:readonly` | Reading a Lark Doc requires read scope |
| `wiki:wiki:readonly` | Traversing the wiki space to find the page |
| `wiki:wiki` | Updating a wiki node requires write scope |

**Authority path:** user — doc reading and wiki editing are user-identity operations.

**Status:** ✅ passing (3 scopes)

---

## Case 3 — CRM record creation + follow-up message (was failing)

**Task:** `create crm record and send a follow-up message`

**Expected scopes:**
| Scope | Why |
|---|---|
| `base:record:created` | CRM record written into Lark Base |
| `base:record:readonly` | Reading existing records to avoid duplicates |
| `bitable:app` | App-level access required to write into a Bitable app |
| `contact:user.base:readonly` | Resolving the customer's user identity from directory |
| `im:message:send_as_bot` | Sending the follow-up message as a bot |

**Authority path:** mixed — record creation is user, IM send is bot. Compound tasks
require the agent to hold both authority types or route each action through the
appropriate identity.

**Before fix:** 1 scope (`im:message:send_as_bot` only — Base scopes were missed)
**Root cause:** keyword pattern `record.*create` missed natural English word order `create.*record`
**Status:** ✅ passing (5 scopes)

---

## Case 4 — Update existing customer record

**Task:** `update the customer record after the meeting`

**Expected scopes:**
| Scope | Why |
|---|---|
| `base:record:readonly` | Read before update to verify record exists |
| `bitable:app` | App-level access is required to modify a Bitable app |
| `bitable:record` | Record update permission is required for the write path |

**Note:** This case intentionally produces fewer scopes than Case 3. No IM send
and no CRM creation flow are involved, but an actual update still needs the
Bitable write scopes in addition to the pre-read.

**Authority path:** user

**Status:** ✅ passing (3 scopes)

---

## Case 5 — Route expense to approval + notify manager (was failing)

**Task:** `route expense to approval and notify the manager`

**Expected scopes:**
| Scope | Why |
|---|---|
| `base:record:created` | Expense record creation (implied by "expense") |
| `approval:instance:write` | Routing to approval requires submitting an instance |
| `im:message:send_as_bot` | "notify the manager" — IM notification as bot |

**Authority path:** mixed — expense creation is user, approval submission is user,
manager notification is bot.

**Before fix:** 1 scope only — `\bexpense\b` bare keyword had been dropped by linter,
leaving only the IM notify match.
**Root cause:** linter replaced `r"expense|..."` with a verb-prefixed pattern that
required "create expense" rather than bare "expense".
**Status:** ✅ passing (3 scopes)

---

## Case 6 — Upload file to Drive + update wiki (was failing)

**Task:** `upload the contract file to drive and update the wiki with the key terms`

**Expected scopes:**
| Scope | Why |
|---|---|
| `drive:file:create` | Uploading a file to Lark Drive |
| `wiki:wiki:readonly` | Traversing the wiki space |
| `wiki:wiki` | Updating wiki node content |

**Authority path:** user — both Drive upload and wiki edit are user-identity actions.

**Before fix:** 2 scopes (wiki only — Drive upload missed)
**Root cause:** pattern `upload\s+file` required "upload" immediately before "file";
"upload the contract file" has intervening words. Fixed to `upload\b`.
**Status:** ✅ passing (3 scopes)

---

## Case 7 — CRM lead record + schedule follow-up meeting (was failing)

**Task:** `create a lead record and schedule a follow-up meeting`

**Expected scopes:**
| Scope | Why |
|---|---|
| `base:record:created` | Lead record written into Lark Base |
| `base:record:readonly` | Existence check before creation |
| `bitable:app` | App-level access for the Bitable CRM app |
| `calendar:calendar` | Creating a calendar event for the follow-up |
| `contact:user.base:readonly` | Looking up the lead's user identity |

**Authority path:** user — this task describes record creation plus calendar scheduling,
but does not explicitly request an IM send.

**Note on scope count:** The minimum correct result is 5 scopes. If
`im:message:send_as_bot` appears here, that is an over-permission bug because the
task mentions a follow-up meeting, not a follow-up message.

**Before fix:** calendar scope missing because `schedule a follow-up meeting` uses
a hyphen — `\w+` does not match `follow-up`. Fixed to `\S+`.
**Status:** ✅ passing (5 scopes)

---

## Case 8 — Attendance records + timesheet report

**Task:** `read the attendance records and generate a timesheet report`

**Expected scopes:**
| Scope | Why |
|---|---|
| `attendance:record:readonly` | Reading attendance check-in data |
| `sheets:spreadsheet` | Generating the report into a spreadsheet |

**Authority path:** user

**Status:** ✅ passing (2 scopes)

---

## Known gaps and next improvements

| Gap | Impact | Priority |
|---|---|---|
| user / bot / tenant authority explanation not shown in CLI output | Harder to understand which identity to provision | High |
| No verification of scope grant against actual Lark auth token | Gaps only visible at runtime | Medium |
| Approval `act` vs `submit` distinction not always inferred correctly | Wrong authority type for approvers | Low |

---

## Regression command

Run all 8 cases and check scope counts:

```bash
for desc in \
  "create expense report and request approval" \
  "read a document and update the wiki page" \
  "create crm record and send a follow-up message" \
  "update the customer record after the meeting" \
  "route expense to approval and notify the manager" \
  "upload the contract file to drive and update the wiki with the key terms" \
  "create a lead record and schedule a follow-up meeting" \
  "read the attendance records and generate a timesheet report"
do
  count=$(larc auth suggest "$desc" 2>&1 | grep "Required scopes" | grep -o '[0-9]*' | head -1)
  echo "[$count] $desc"
done
```

Expected output (minimum scope counts):
```
[2] create expense report and request approval
[3] read a document and update the wiki page
[5] create crm record and send a follow-up message
[3] update the customer record after the meeting
[3] route expense to approval and notify the manager
[3] upload the contract file to drive and update the wiki with the key terms
[5] create a lead record and schedule a follow-up meeting
[2] read the attendance records and generate a timesheet report
```
