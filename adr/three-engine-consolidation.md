# ADR: Consolidate to Three Rails Engines (Superseded)

**Status:** Superseded (2026-04-17)

**Superseded by:** `adr/four-engine-restoration-and-base-contract.md`

## Summary

This ADR previously changed the target architecture from four engines to three by merging the
business and delivery surfaces into one Regional engine.

That direction is no longer active.

The current target architecture is:

- `Identity`
- `Gateway`
- `Foundation`
- `Distributor`

## Historical Decision

The superseded decision proposed these canonical engines:

- `Identity`
- `Global`
- `Regional`

It also assumed that extracted `station` and `press` code would be consolidated into a single
Regional engine.

## Why It Was Superseded

The repository direction changed again and restored the four-engine split.

The active architecture now keeps business operations and delivery as separate engines:

- `Foundation` owns the `base.*` public contract
- `Distributor` owns the `post.*` public contract

The canonical engine names `Gateway`, `Foundation`, and `Distributor` replace the superseded
`Global`, `Regional`, and `Publisher`-style directions.

## Notes Preserved From This ADR

The following principles remain valid even though the three-engine topology was abandoned:

- database boundaries should stay explicit
- cross-engine SQL coupling should be avoided
- canonical host and ENV naming should be explicit
- public contracts should be defined separately from internal namespace cleanup

## Do Not Use As Current Source Of Truth

Do not use this ADR as the source of truth for:

- engine names
- engine count
- deploy modes
- host ownership
- public route helper names
- canonical ENV names

## Current Source Of Truth

- `adr/four-engine-restoration-and-base-contract.md`
