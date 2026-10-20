# frozen_string_literal: true

require "test_helper"

module Publishing
  module Info
    module Com
      class PublicationTest < ActiveSupport::TestCase
        test "public_id is a fixed 21-character NanoID" do
          assert_public_id_fixed_length(::Publishing::Info::Com::Publication)
        end
      end
    end
  end
end
