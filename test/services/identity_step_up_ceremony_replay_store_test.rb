# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityStepUpCeremonyReplayStoreTest < ActiveSupport::TestCase
  test "for returns a store for each known surface" do
    assert_kind_of IdentityStepUpCeremonyReplayStore, IdentityStepUpCeremonyReplayStore.for(:app)
    assert_kind_of IdentityStepUpCeremonyReplayStore, IdentityStepUpCeremonyReplayStore.for(:org)

  end

  test "for raises when the surface is invalid" do
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyReplayStore.for(:invalid)
    end
  end
end
