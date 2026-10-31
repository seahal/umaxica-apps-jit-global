# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreRouteHostSourceInvariantTest < ActiveSupport::TestCase
  test "public Core routes use canonical boot hosts without environment fallbacks" do
    source = Rails.root.join("config/routes/core.rb").read

    assert_includes source, "boot_config.fetch(:hosts).core_service.host"
    assert_includes source, "boot_config.fetch(:hosts).core_staff.host"
    # The corporate BFF host is retired with the corporate identity surface.
    assert_no_match(/core_corporate/, source)
    assert_no_match(/PUBLIC_CORE_(?:SERVICE|CORPORATE|STAFF)_URL/, source)
    assert_no_match(/core\.(?:app|com|org)\.localhost/, source)
  end
end
