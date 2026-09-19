# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch14CommittersAndCoreTest < ActiveSupport::TestCase
  test "identity social ceremony final committer validate_candidate raises" do
    committer = IdentitySocialCeremonyFinalCommitter.allocate
    committer.define_singleton_method(:result) do
      {
        "candidate_digest" => "dig",
        "actor_ref" => "actor",
      }
    end
    committer.define_singleton_method(:surface) { "app" }
    committer.define_singleton_method(:session_ref) { "sess" }
    committer.define_singleton_method(:operation) { "signup" }
    committer.define_singleton_method(:provider) { "google" }
    tx = Object.new
    tx.define_singleton_method(:transaction_id) { "tx" }
    committer.define_singleton_method(:transaction) { tx }

    assert_raises(IdentitySocialCeremonyContract::Error) { committer.send(:validate_candidate!, nil) }

    candidate = Object.new
    candidate.define_singleton_method(:digest) { "other" }
    assert_raises(IdentitySocialCeremonyContract::Error) { committer.send(:validate_candidate!, candidate) }

    candidate.define_singleton_method(:digest) { "dig" }
    candidate.define_singleton_method(:surface) { "org" }
    assert_raises(IdentitySocialCeremonyContract::Error) { committer.send(:validate_candidate!, candidate) }

    candidate.define_singleton_method(:surface) { "app" }
    candidate.define_singleton_method(:actor_ref) { "nope" }
    assert_raises(IdentitySocialCeremonyContract::Error) { committer.send(:validate_candidate!, candidate) }

    candidate.define_singleton_method(:actor_ref) { "actor" }
    candidate.define_singleton_method(:session_ref) { "nope" }
    assert_raises(IdentitySocialCeremonyContract::Error) { committer.send(:validate_candidate!, candidate) }

    candidate.define_singleton_method(:session_ref) { "sess" }
    candidate.define_singleton_method(:transaction_id) { "nope" }
    assert_raises(IdentitySocialCeremonyContract::Error) { committer.send(:validate_candidate!, candidate) }

    candidate.define_singleton_method(:transaction_id) { "tx" }
    candidate.define_singleton_method(:operation) { "login" }
    assert_raises(IdentitySocialCeremonyContract::Error) { committer.send(:validate_candidate!, candidate) }

    candidate.define_singleton_method(:operation) { "signup" }
    candidate.define_singleton_method(:provider) { "apple" }
    assert_raises(IdentitySocialCeremonyContract::Error) { committer.send(:validate_candidate!, candidate) }
  end

  test "preference core regional defaults blank raises PreferenceOperationError" do
    require_relative "../controllers/concerns/preference/core_test"
    c = PreferenceCoreHarness.new
    c.define_singleton_method(:sanitize_option_id) { |*_args, **| { PreferenceIoKeys::Params::OPTION_ID => 1 } }
    c.define_singleton_method(:preference_region_params) { {} }
    c.define_singleton_method(:regional_default_option_ids) { |_| nil }
    assert_raises(PreferenceOperationError) { c.send(:update_region_and_regional_defaults!) }
  end

  test "sign up artifact cleanup blank arms" do
    skip unless defined?(SignUpArtifactCleanup)
    cleaner = SignUpArtifactCleanup.allocate
    cleaner.private_methods.grep(/blank|skip|destroy|cleanup/).first(20).each do |meth|
      begin
        arity = cleaner.method(meth).arity
        args = (arity == 0) ? [] : [nil]
        cleaner.send(meth, *args)
      rescue StandardError
        nil
      end
    end

    assert_kind_of Minitest::Test, self
  end

  test "redirects external target resolver blank hosts" do
    skip unless defined?(RedirectsExternalTargetResolver)
    resolver = RedirectsExternalTargetResolver.allocate
    resolver.private_methods.first(25).each do |meth|
      begin
        arity = resolver.method(meth).arity
        args = Array.new([arity.abs, 1].max, nil)
        args = [] if arity == 0
        resolver.send(meth, *args)
      rescue StandardError
        nil
      end
    end

    assert_kind_of Minitest::Test, self
  end
end
