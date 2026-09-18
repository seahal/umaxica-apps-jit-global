# URL Identifier and Reserved Character Policy

This policy defines the allocation of ASCII symbols in public URL identifiers. A reserved symbol is
not available for an unrelated identifier merely because the application does not currently assign
it a meaning.

## Allocations

| Symbol | Allocation                                      | Rule                                                                                    |
| ------ | ----------------------------------------------- | --------------------------------------------------------------------------------------- |
| `@`    | Core Avatar human-readable handle prefix        | Use as a fixed URL prefix; do not include it in the handle value.                       |
| `~`    | Reserved for a future document or URL namespace | Do not use it as an identifier, handle, slug, or prefix.                                |
| `$`    | Non-URL identifier notation                     | It may appear in human notation outside URLs, but never as a URL prefix or path syntax. |
| `#`    | URI fragment delimiter                          | Do not use it in an identifier or custom URL syntax.                                    |
| `?`    | URI query delimiter                             | Do not use it in an identifier, handle, or slug.                                        |
| `/`    | URI path-segment separator                      | Use only to separate path segments, never as identifier data.                           |
| `\\`   | Prohibited identifier character                 | Reject it, including encoded representations, in URL identifier components.             |
| `!`    | Reserved                                        | Do not use it in a URL namespace, identifier prefix, handle, or slug syntax.            |

The Core Avatar route may therefore use a prefix-parameter shape equivalent to `@{$handle}` in the
router that owns that public surface. The `@` belongs to the route syntax; it is not part of the
stored handle.

## Non-goals and change control

This policy does not create a route, change an existing identifier validator, or assign a meaning to
`~`. It also does not authorize a new Avatar feature. A future URL namespace or identifier syntax
must explicitly amend this allocation before using a reserved symbol. Percent-encoding must not be
used to bypass the policy or to make parser-dependent spellings equivalent to an allowed identifier.

The symbols in this document are URL syntax and namespace controls only. They are not
authentication, authorization, rate-limit, audit, or user-identity evidence.
