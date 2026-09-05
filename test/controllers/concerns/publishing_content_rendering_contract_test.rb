# frozen_string_literal: true

require "test_helper"

class PublishingContentRenderingContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "surface and audience are read from explicit constants not class names" do
    klass =
      Class.new(ApplicationController) do
        include PublishingContentRendering

        const_set(:PUBLISHING_AUDIENCE, "com")
        const_set(:PUBLISHING_SURFACE, "news")
      end

    assert_equal "com", klass.publishing_audience
    assert_equal "news", klass.publishing_surface
    assert_not_equal "com", klass.name.to_s.downcase
  end

  test "a missing surface constant is a contract error" do
    klass =
      Class.new(ApplicationController) do
        include PublishingContentRendering

        const_set(:PUBLISHING_AUDIENCE, "app")
      end

    error = assert_raises(NameError) { klass.publishing_surface }

    assert_includes error.message, "PUBLISHING_SURFACE"
  end
end
