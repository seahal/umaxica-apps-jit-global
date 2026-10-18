# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalIdentityRepositoryPortTest < ActiveSupport::TestCase
  class IncompleteRepository
    include ExternalAuthentication::ExternalIdentityRepositoryPort
  end

  setup do
    @repository = IncompleteRepository.new
  end

  test "port methods raise NotImplementedError until an adapter implements them" do
    assert_raises(NotImplementedError) { @repository.find_by_subject("sub", lock: false) }
    assert_raises(NotImplementedError) { @repository.find_for_user(Object.new) }
    assert_raises(NotImplementedError) { @repository.find_by_subject_for_link("sub", lock: false) }
    assert_raises(NotImplementedError) { @repository.find_for_user_for_link(Object.new) }
    assert_raises(NotImplementedError) do
      @repository.build_for_user(user: Object.new, principal: Object.new, credential_candidate: Object.new)
    end
    assert_raises(NotImplementedError) do
      @repository.refresh_credentials!(Object.new, principal: Object.new, credential_candidate: Object.new)
    end
    assert_raises(NotImplementedError) { @repository.assign_to_user(Object.new, Object.new) }
    assert_raises(NotImplementedError) { @repository.activate!(Object.new) }
    assert_raises(NotImplementedError) { @repository.destroy!(Object.new) }
    assert_raises(NotImplementedError) { @repository.refresh_token_for(Object.new) }
  end
end
