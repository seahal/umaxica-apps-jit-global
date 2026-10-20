# Owner record lookups

An owner reference comes from the persisted, surface-specific source record. Loading that owner does
not grant access: the existing caller authentication, policy, lifecycle checks and locks still
decide whether the requested action may proceed.

For the owner lookups covered by the Brakeman remediation, query the declared, fixed-name
association explicitly:

```ruby
contact.association(:user).tap { |owner| owner.reset_scope }.scope.take
```

The association name is a literal selected by the existing explicit record-type branch. Request
input never chooses an association, class or operation. The association's declared foreign key
constrains the relation. Reset its scope before querying: a previously accessed association can
retain a predicate built from an older foreign-key value. The explicit query also avoids returning a
cached principal whose lifecycle has changed.

Use `take!` when the preceding implementation required a matching record and raised
`ActiveRecord::RecordNotFound`. Use `take` when absence is an expected nullable lookup result that
the caller handles. Preserve any additional owner constraints, such as the sign-in receipt's
principal ID, in the query itself.

The application enables strict loading. Ordinary association readers and `reload_<association>` can
trigger a lazy-loading violation; changing strict-loading settings would weaken that guard. These
lookups deliberately issue a visible query through the named association scope, without lazy-loading
or populating a cached target. They neither reload the source record nor discard its unsaved
attributes. They add no application-owned dynamic class or method resolution.

Current-root-token lookups instead query the stable device session's token collection, retaining
both the current token ID and the owning device-session constraint. Existing device-first and token
locks remain in place.

The public action tests, ownership refusal tests and session-boundary tests remain the behavioral
authority. A clean scanner result is additional evidence, not proof of absence of vulnerabilities.
