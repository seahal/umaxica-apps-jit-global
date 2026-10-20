# frozen_string_literal: true

require "test_helper"

module Publishing
  module News
    module App
      class VocabularyTest < ActiveSupport::TestCase
        test "public_id is a fixed 21-character NanoID" do
          assert_public_id_fixed_length(::Publishing::News::App::Vocabulary)
        end
      end
    end
  end
end
