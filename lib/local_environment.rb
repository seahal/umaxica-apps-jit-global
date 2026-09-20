# frozen_string_literal: true

require "pathname"

# Minimal dotenv-compatible loader for the repository's non-secret development contract.
# It intentionally does not execute shell syntax and never overrides an explicitly exported
# environment variable. Production processes do not read repository-local environment files.
module LocalEnvironment
  module_function

  KEY = /\A[A-Za-z_][A-Za-z0-9_]*\z/.freeze

  def load!
    return if ENV["RAILS_ENV"] == "production" || ENV["RACK_ENV"] == "production"

    path = Pathname.new(ENV.fetch("UMAXICA_ENV_FILE", default_path))
    path = Pathname.new(File.expand_path("../.env", __dir__)) unless path.file?
    path = Pathname.new(File.expand_path("../.env.example", __dir__)) unless path.file?
    return unless path.file?

    path.each_line do |line|
      name, value = parse(line)
      ENV[name] = value if name && !ENV.key?(name)
    end
  end

  def default_path
    File.expand_path("../.env", __dir__)
  end

  def parse(line)
    text = line.strip
    return [nil, nil] if text.empty? || text.start_with?("#")

    match = text.match(/\A(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)\z/)
    return [nil, nil] unless match && KEY.match?(match[1])

    [match[1], unquote(match[2].strip)]
  end

  def unquote(value)
    if value.length >= 2 && value.start_with?("\"") && value.end_with?("\"")
      return value[1...-1].gsub(/\\([\\"nrt])/) do |escape|
        { "\\" => "\\", '"' => '"', "n" => "\n", "r" => "\r", "t" => "\t" }.fetch(escape)
      end
    end
    return value[1...-1].gsub("\\'", "'") if value.length >= 2 && value.start_with?("'") && value.end_with?("'")

    value.sub(/\s+#.*\z/, "").strip
  end

  private_class_method :unquote
end
