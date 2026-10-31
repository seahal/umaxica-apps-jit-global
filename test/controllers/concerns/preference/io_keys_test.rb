# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceIoKeysTest < ActiveSupport::TestCase
  test "exposes only current display and parameter keys" do
    assert_equal "language", PreferenceIoKeys::Cookies::LANGUAGE
    assert_equal :ct, PreferenceIoKeys::Params::CT
    assert_equal :lx, PreferenceIoKeys::Params::LX
    assert_equal :ri, PreferenceIoKeys::Params::RI
    assert_equal :tz, PreferenceIoKeys::Params::TZ
    assert_equal :option_id, PreferenceIoKeys::Params::OPTION_ID
  end

  test "preference transport keys do not accept refresh parameters" do
    assert_not PreferenceIoKeys::Params.const_defined?(:REFRESH_TOKEN, false)
    assert_not PreferenceIoKeys::Cookies.const_defined?(:REFRESH_BASENAME, false)
    assert_not PreferenceIoKeys::Cookies.const_defined?(:DBSC_BASENAME, false)
  end
end
