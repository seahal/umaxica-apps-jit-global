# Method Visibility and Concern Inclusion Hooks

Two architecture rules are enforced statically by custom RuboCop cops in
`lib/rubocop/cop/umaxica/`. Both are normative for new and modified application code under `app/`
and `lib/`.

## Rule 1 — no concern inclusion hooks (`Umaxica/NoConcernInclusionHooks`)

`included do` and `prepended do` are forbidden in application code.

`ActiveSupport::Concern` supports these hooks; this repository declines to use them. Including a
module must not silently register behavior on the host class — callbacks, validations, scopes,
associations, `attribute`, `class_attribute`, enums, delegation, `before_action` and friends, or any
other framework registration. A reader of the host class must be able to see what it does without
opening every included module.

A concern may still supply shared implementation methods. That is not what this rule bans.

```ruby
# bad
module Normalizable
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_name
  end
end

# good
module Normalizable
  private

  def normalize_name
  end
end

class User < ApplicationRecord
  include Normalizable

  before_validation :normalize_name
end
```

Existing hooks are legacy debt recorded in the baseline. Do not migrate one mechanically: the hook
body may depend on inclusion order, on the host's table, or on being evaluated in the host's context.
Migrate only with tests that cover the behavior being moved.

## Rule 2 — explicit method visibility (`Umaxica/ExplicitMethodVisibility`)

A method defined directly in a class, module or `class << self` body must sit under a declared
visibility. Ruby's `public` default is not accepted as a declaration: a public method must be public
because someone decided it is part of the externally callable contract.

Accepted forms: a bare `public` / `protected` / `private` / `module_function` section, an inline
`private def ...`, and a name listed in `public :foo`, `protected :foo`, `private :foo`,
`public_class_method :foo` or `private_class_method :foo`. `def self.foo` has no lexical section
form, so it must be named by `public_class_method` / `private_class_method`, or be written inside a
`class << self` body that has sections.

Choose the narrowest correct visibility:

1. `private` — implementation detail. The default answer.
2. `protected` — only for a real extension or collaboration boundary: a subclass extension point, an
   explicit-receiver call between peer instances of the same abstraction, an inheritance-oriented
   API. Not a compromise between the other two.
3. `public` — an intentional external contract.

Framework entry points stay public and must be declared so deliberately: routed controller actions,
mailer actions, job execution methods, policy predicates, and a service's `call`. Controller
callbacks, parameter helpers, resource loaders, response helpers and authorization helpers are
private — a method that accidentally becomes public in a controller becomes a routable action.

`initialize` and its siblings are exempt: Ruby already makes them private.

Methods produced by blocks and metaprogramming (`define_method`, `class_eval`, Rails DSL blocks) are
out of scope. Their visibility cannot be expressed with a lexical modifier, so the cop does not look
inside blocks at all.

A test is never a reason to widen visibility. Do not make a method public, keep it public, or
promote `private` to `protected` because a test calls it, and do not add a test-only wrapper or reach
in with `send`. If reducing visibility breaks a test, the test is coupled to an implementation
detail; move it to the public behavior. See `.agents/harnesses/rules/generic/no-test-only-code.mdc`.

## Baseline and ratchet

Existing violations are technical debt, not permission.

- `.rubocop_todo.yml` — per-cop `Exclude` lists, so `bin/rubocop` (CI step "Style: Ruby") stays green
  while rejecting any violation in a file that is not already in debt.
- `.rubocop/architecture_baseline.yml` — per-file offense counts.
  `test/tooling/architecture_baseline_test.rb` (CI step "Tests: Rails") re-measures the repository
  with the excludes ignored and fails if any file exceeds its recorded count, or if the baseline
  still lists a file that is now clean.

Both artifacts are generated together by `bin/rails architecture:baseline`. Regenerate it only to
record a reduction. Regenerating it to absorb a violation you just introduced defeats the mechanism
and will show up as a growing count in review.

When you touch a file that carries debt, prefer clearing its entries over preserving them.
