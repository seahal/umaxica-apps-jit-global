# frozen_string_literal: true

# Rapid re-login guard: a new root login may not be established within this window of the
# previous root login of the same actor on the same surface. The anchor is
# `root_login_established_at` (AuthenticationBase#check_login_cooldown!,
# adr/root-login-establishment-boundary.md); signing out does not clear it. A zero duration
# disables the gate, which tests use only through test/support/login_cooldown_helper.rb.
Rails.application.config.x.authentication.login_cooldown = 30.seconds
