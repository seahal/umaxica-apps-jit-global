# typed: false
# frozen_string_literal: true

# Provides the default HTTP cache policy for Global and Publishing controller families.
#
# These controllers are deliberately non-cacheable unless an action explicitly opts into caching.
# The default is fail-safe: a newly added action that does not make a cache decision must send
# `Cache-Control: no-store`. Cacheability is a performance optimization; forgetting it costs a
# re-transfer, while forgetting to forbid it on a response that carries session, credential, or other
# private state is a disclosure defect. Human review is not the boundary that prevents that defect;
# this default is. See adr/global-and-publishing-default-no-store-policy.md and
# docs/reference/http-cache-policy.md.
#
# This module intentionally does not register callbacks through `included do`. Each policy-root
# controller must explicitly declare:
#
#   include ::DefaultNoStore
#   prepend_before_action :apply_default_no_store
#
# Keeping callback registration at the policy root makes the cache boundary visible in the
# controller inheritance tree and prevents concern composition from silently changing response
# semantics. Subclasses inherit the declaration and never repeat it.
#
# Why `prepend_before_action`:
#
# Some requests terminate before the controller action because of the FQDN availability gate, rate
# limits, authentication checks, redirects, or other callbacks. Applying `no_store` first ensures
# those controller responses inherit the safe default as well. The callback only replaces the
# response's in-memory cache-control directives; it reads no request input, spends no rate-limit
# budget, and touches no session, so it may run ahead of the availability gate.
#
# A subclass that prepends its own callback and then calls `ensure_fqdn_gate_first!` pushes this
# callback out of first place. Such a subclass re-prepends it immediately afterwards:
#
#   prepend_before_action :some_early_check!
#   ensure_fqdn_gate_first!
#   prepend_before_action :apply_default_no_store
#
# That restores the order (no-store, availability gate, subclass callback); it is a reordering of
# the inherited callback, not a second policy declaration. The same applies when an included
# concern does the prepending in its own hook (`OidcRpLogoutLauncher` on
# `Edit::Org::Sign::OutsController`): the controller re-prepends after the include.
# test/security/invariants/default_no_store_policy_invariant_test.rb fails when this order is broken.
#
# How an action opts into caching:
#
# Do NOT skip or remove this callback (`skip_before_action :apply_default_no_store` is rejected by
# the invariant test). A cacheable action must explicitly replace the default policy from inside the
# action by using Rails' conditional/freshness cache APIs, for example:
#
#   fresh_when(...)
#   stale?(...)
#   expires_in(...)
#   expires_now
#   http_cache_forever(...)
#
# In Rails 8.2, `fresh_when` (and so `stale?`) and `expires_in` (and so `http_cache_forever`) delete
# the `no_store` directive before applying their own, and `expires_now` replaces every directive with
# `no-cache`. The exception is therefore visible at the action that owns the representation. A
# response whose body varies by the signed-in subject must not opt into `public`.
#
# New code must not opt into caching by directly mutating the `Cache-Control` response header or
# `response.cache_control`. A cacheable header written directly is overridden by this default when
# the response is committed: Rails merges the header into the directive hash, and `no_store` wins.
#
# This policy does not apply to controller families owned by the Regional plane, Core, Palm, or
# Warp. When a policy root moves to Regional ownership, that change removes this module from the
# root and defines the Regional cache contract at the same time. Static/fingerprinted assets served
# by Propshaft or Vite are also outside this controller policy.
#
# Contract with the including class: none beyond being an ActionController::Base or
# ActionController::API controller (it calls the framework's `no_store`).
module DefaultNoStore
  private

  def apply_default_no_store
    no_store
  end
end
