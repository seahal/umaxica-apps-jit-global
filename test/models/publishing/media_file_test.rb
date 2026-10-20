# frozen_string_literal: true

require "test_helper"

module Publishing
  class MediaFileTest < ActiveSupport::TestCase
    test "public_id is a fixed 21-character NanoID" do
      assert_public_id_fixed_length(::Publishing::MediaFile)
    end
  end
end
