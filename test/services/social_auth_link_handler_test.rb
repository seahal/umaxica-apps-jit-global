# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthLinkHandlerTest < ActiveSupport::TestCase
  Client = Struct.new(:id)
  Identity = Struct.new(:uid, :provider, :user_id, :active?)

  test "rejects linking a second provider identity with a different subject" do
    repository = Repository.new(current_user_identity: Identity.new("original-subject", "google", 1, true))

    error =
      assert_raises(SocialAuth::ConflictError) do
        call_handler(repository:, uid: "replacement-subject")
      end

    assert_equal "errors.social_auth.identity_conflict", error.i18n_key
    assert_equal :conflict, error.status_code
  end

  test "rejects a provider identity already linked to another client" do
    repository = Repository.new(subject_identity: Identity.new("shared-subject", "google", 2, true))

    error =
      assert_raises(SocialAuth::ConflictError) do
        call_handler(repository:, uid: "shared-subject")
      end

    assert_equal "errors.social_auth.linked_to_another_user", error.i18n_key
    assert_equal :conflict, error.status_code
  end

  test "turns a unique-identity race into the public conflict response" do
    repository = Repository.new(raise_on_subject_lookup: true)

    error =
      assert_raises(SocialAuth::ConflictError) do
        call_handler(repository:, uid: "racing-subject")
      end

    assert_equal "errors.social_auth.identity_conflict", error.i18n_key
    assert_equal :conflict, error.status_code
  end

  test "refreshes an active identity already linked to the current client" do
    identity = Identity.new("existing-subject", "google", 1, true)
    repository = Repository.new(subject_identity: identity)

    result = call_handler(repository:, uid: "existing-subject")

    assert_equal Client.new(1), result.fetch(:user)
    assert_equal identity, result.fetch(:identity)
    assert_equal({ user_id: 1 }, result.fetch(:jwt_payload))
    assert_equal identity, repository.refreshed_identity
  end

  private

  def call_handler(repository:, uid:)
    SocialAuthLinkHandler.call(
      principal: Object.new,
      credential_candidate: nil,
      current_client: Client.new(1),
      repository: repository,
      provider: "google",
      uid: uid,
    )
  end

  class Repository
    attr_reader :refreshed_identity

    def initialize(current_user_identity: nil, subject_identity: nil, raise_on_subject_lookup: false)
      @current_user_identity = current_user_identity
      @subject_identity = subject_identity
      @raise_on_subject_lookup = raise_on_subject_lookup
    end

    def find_for_user(_client)
      @current_user_identity
    end

    def find_for_user_for_link(_client)
      @current_user_identity
    end

    def find_by_subject(*)
      raise ActiveRecord::RecordNotUnique if @raise_on_subject_lookup

      @subject_identity
    end

    def find_by_subject_for_link(*)
      raise ActiveRecord::RecordNotUnique if @raise_on_subject_lookup

      @subject_identity
    end

    def refresh_credentials!(identity, *)
      @refreshed_identity = identity
    end
  end
end
