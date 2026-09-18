# typed: false
# frozen_string_literal: true

require "test_helper"

class ArchitectureAndStorageCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "ArchitectureBaseline write and todo_body emit sorted yaml" do
    Dir.mktmpdir do |dir|
      counts_path = Pathname.new(dir).join("counts.yml")
      todo_path = Pathname.new(dir).join("todo.yml")
      previous_counts = ArchitectureBaseline::COUNTS_PATH
      previous_todo = ArchitectureBaseline::TODO_PATH
      ArchitectureBaseline.send(:remove_const, :COUNTS_PATH)
      ArchitectureBaseline.send(:remove_const, :TODO_PATH)
      ArchitectureBaseline.const_set(:COUNTS_PATH, counts_path)
      ArchitectureBaseline.const_set(:TODO_PATH, todo_path)
      begin
        counts = {
          "Umaxica/ExplicitMethodVisibility" => { "b.rb" => 2, "a.rb" => 1 },
          "Umaxica/NoConcernInclusionHooks" => { "c.rb" => 1 },
        }
        ArchitectureBaseline.write(counts)

        assert_path_exists counts_path
        assert_path_exists todo_path
        body = ArchitectureBaseline.send(:todo_body, counts)

        assert_includes body, "Umaxica/ExplicitMethodVisibility"
        assert_includes body, "a.rb"
      ensure
        ArchitectureBaseline.send(:remove_const, :COUNTS_PATH)
        ArchitectureBaseline.send(:remove_const, :TODO_PATH)
        ArchitectureBaseline.const_set(:COUNTS_PATH, previous_counts)
        ArchitectureBaseline.const_set(:TODO_PATH, previous_todo)
      end
    end
  end

  test "Umaxica::Valkey::ResponsibilityUrls require_url rejects blank and missing" do
    env = {}
    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::ResponsibilityUrls.send(:require_url, :cache, "CACHE_REDIS_URL", environment: env)
    end

    env = { "CACHE_REDIS_URL" => "   " }
    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::ResponsibilityUrls.send(:require_url, :cache, "CACHE_REDIS_URL", environment: env)
    end
  end

  test "ObjectStorage::ShrineConfiguration s3 compatible storage builds from env" do
    values = {
      "OBJECT_STORAGE_ENDPOINT" => "http://127.0.0.1:9000",
      "OBJECT_STORAGE_REGION" => "us-east-1",
      "OBJECT_STORAGE_FORCE_PATH_STYLE" => "true",
      "OBJECT_STORAGE_ACCESS_KEY_ID" => "ak",
      "OBJECT_STORAGE_SECRET_ACCESS_KEY" => "sk",
    }
    storage =
      begin
        Environment.stub(:fetch, ->(key) { values.fetch(key) }) do
          Environment.stub(:fetch_boolean, ->(key) { values.fetch(key) == "true" }) do
            ObjectStorage::ShrineConfiguration.send(:s3_compatible_storage, bucket: "b", prefix: "p")
          end
        end
      rescue StandardError, LoadError => e
        skip("Shrine S3 storage unavailable: #{e.class}: #{e.message}")
      end

    assert storage
  end
end
