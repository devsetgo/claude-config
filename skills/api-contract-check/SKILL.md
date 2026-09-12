---
name: api-contract-check
description: Classify API/schema changes in the diff as breaking or non-breaking — required vs optional fields, type changes, removed/renamed fields or endpoints, changed defaults or validation. Use before opening a PR that touches a public API, schema, or library contract.
---

# API Contract Check

Determine whether changes to a public contract are breaking for existing
consumers — not just whether the code compiles or the tests pass.

"Contract" here means any interface external callers depend on: a REST/
GraphQL API, an RPC/protobuf schema, a public library's exported types and
functions, an event/message schema, or a database schema other services
query directly.

## Steps

1. Identify what the contract actually is in this project: an OpenAPI/
   Swagger spec, GraphQL SDL, protobuf/gRPC `.proto` files, a public
   library's exported symbols, or a hand-maintained API doc. If none of
   those exist, treat the actual request/response handling code as the de
   facto contract.

2. Diff the contract against the base branch/last release tag (not just
   read the new version in isolation), and classify each change:

   **Breaking:**
   - a required field/parameter added (existing callers didn't send it)
   - a field, parameter, endpoint, or method removed or renamed
   - a field's type narrowed or changed (e.g. `string` → `bool`,
     nullable → non-nullable)
   - an optional field made required, or a field callers already treat as
     always-present made optional/nullable
   - a default value changed in a way that changes existing callers'
     observed behavior
   - validation tightened so a previously-accepted input is now rejected
   - status/error-code semantics changed for an existing case

   **Non-breaking:**
   - a new optional field or parameter added
   - a new endpoint or method added
   - a new enum value added — *if* consumers are expected to handle
     unknown values gracefully; call out this assumption explicitly, it
     doesn't always hold
   - a type widened (e.g. `int32` → `int64`, non-nullable → nullable)
   - validation relaxed so a previously-rejected input is now accepted

3. For genuinely ambiguous cases (e.g. a required field added to a
   request body with no known existing consumers yet), state the
   ambiguity and the assumption made rather than silently picking a side.

## Output

A list of contract changes, each tagged `BREAKING` or `NON-BREAKING`,
with: the symbol/field/endpoint, what changed, and who it affects. For
`BREAKING` items, suggest a mitigation where one is straightforward
(version the endpoint, add the field with a backward-compatible default,
deprecate-then-remove over two releases). See
`skills/_shared/finding-format.md` for the standalone-vs-delegated
reporting convention (relevant callers include `pr-check`, `release-check`,
and `commit-message` deciding whether a `!`/`BREAKING CHANGE` marker is
warranted).
