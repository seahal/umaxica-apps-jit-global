# frozen_string_literal: true

require "test_helper"

module Publishing
  module Docs
    module App
      class EntryRevisionTest < ActiveSupport::TestCase
        test "public_id is a fixed 21-character NanoID" do
          assert_public_id_fixed_length(::Publishing::Docs::App::EntryRevision)
        end
      end
    end
  end
end
