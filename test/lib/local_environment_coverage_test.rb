# frozen_string_literal: true

require "test_helper"

# LocalEnvironment is required at boot before SimpleCov starts, so a normal suite
# sees 0% for lib/local_environment.rb. Reloading the file under the coverage
# run re-instruments the methods for the per-file and branch floors.
class LocalEnvironmentCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    load Rails.root.join("lib/local_environment.rb").to_s
  end

  test "load! is a no-op in production" do
    previous = ENV["RAILS_ENV"]
    ENV["RAILS_ENV"] = "production"

    assert_nil LocalEnvironment.load!
  ensure
    ENV["RAILS_ENV"] = previous
  end

  test "load! fills missing keys from a dotenv-compatible file and preserves exports" do
    Dir.mktmpdir do |dir|
      env_file = File.join(dir, "env")
      File.write(env_file, <<~ENV)
        # comment
        EXPLICIT_KEEP=from-process
        NEW_KEY=value
        export EXPORTED=yes
        QUOTED="hello"
        SINGLE='world'
        WITH_COMMENT=ok # trailing
        bad-key=1
      ENV

      ENV.delete("NEW_KEY")
      ENV.delete("EXPORTED")
      ENV.delete("QUOTED")
      ENV.delete("SINGLE")
      ENV.delete("WITH_COMMENT")
      ENV["EXPLICIT_KEEP"] = "from-process"
      ENV["UMAXICA_ENV_FILE"] = env_file

      LocalEnvironment.load!

      assert_equal "from-process", ENV.fetch("EXPLICIT_KEEP")
      assert_equal "value", ENV.fetch("NEW_KEY")
      assert_equal "yes", ENV.fetch("EXPORTED")
      assert_equal "hello", ENV.fetch("QUOTED")
      assert_equal "world", ENV.fetch("SINGLE")
      assert_equal "ok", ENV.fetch("WITH_COMMENT")
    end
  ensure
    ENV.delete("UMAXICA_ENV_FILE")
    %w(NEW_KEY EXPORTED QUOTED SINGLE WITH_COMMENT).each { |key| ENV.delete(key) }
  end

  test "parse rejects blank, comments, and invalid keys" do
    assert_equal [nil, nil], LocalEnvironment.parse("")
    assert_equal [nil, nil], LocalEnvironment.parse("# hi")
    assert_equal [nil, nil], LocalEnvironment.parse("1BAD=1")
    assert_equal ["OK", "1"], LocalEnvironment.parse("OK=1")
  end

  test "default_path points at the repository .env" do
    assert_equal Rails.root.join(".env").to_s, LocalEnvironment.default_path
  end
end
