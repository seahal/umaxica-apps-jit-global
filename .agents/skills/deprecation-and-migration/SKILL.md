---
name: deprecation-and-migration
description: Plan and execute replacement or retirement with consumer mapping, reference migration and recovery. Use when a change removes an existing contract, storage shape or implementation.
---

# Deprecation and migration

Inventory actual consumers and authoritative contracts before replacing a path, API or data shape.
Distinguish current references from historical evidence. Classify retained content by responsibility;
a directory move alone does not resolve conflicting authority.

Define the replacement, transition order, verification, owner and recovery condition. Keep a rename
and its current callers coherent in the same change. Bounded compatibility is justified only by a
real deployment/migration requirement with an exit condition. Vendor discovery adapters pointing to
one source are not duplicate implementations.

For persistent data, inspect migration assumptions and preservation requirements; obtain explicit
risk and recovery approval before destructive or irreversible operations. A local code approval
is not production authorization. Record observed verification against a revision. Preserve useful
negative knowledge and decision history rather than rewriting them as if the old system never existed.
