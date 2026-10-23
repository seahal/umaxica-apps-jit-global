# typed: false
# frozen_string_literal: true

require "test_helper"

class ReferenceDefaultsTest < ActiveSupport::TestCase
  DEFAULT_MODELS = [
    AreaOccurrenceStatus,
    VisitorOccurrenceStatus,
    DomainOccurrenceStatus,
    EmailOccurrenceStatus,
    IpOccurrenceStatus,
    JwtOccurrenceStatus,
    OperatorPreferenceRegionOption,
    TelephoneOccurrenceStatus,
    ClientOccurrenceStatus,
    ClientEmailStatus,

    ClientPreferenceLanguageOption,
    ClientPreferenceRegionOption,
    ClientStatus,
    ZipOccurrenceStatus,
  ].freeze

  test "reference models ensure their fixed ids exist" do
    DEFAULT_MODELS.each do |model|
      model.ensure_defaults!

      assert_empty model::DEFAULTS - model.where(id: model::DEFAULTS).pluck(:id)
    end
  end
end
