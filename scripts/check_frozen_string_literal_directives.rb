# frozen_string_literal: true

RUBY_SOURCE_PATTERNS = [
  "**/*.rb", "**/*.rake", "**/*.ru", "**/*.gemspec", "**/Gemfile", "**/Rakefile",
  "bin/*",
].freeze

EXCLUDED_PREFIXES = [
  ".git/", ".ruby-lsp/", "vendor/", "node_modules/", "tmp/", "log/",
].freeze

ruby_files =
  Dir.glob(RUBY_SOURCE_PATTERNS, File::FNM_DOTMATCH).uniq.select do |path|
    next false unless File.file?(path)
    next false if EXCLUDED_PREFIXES.any? { |prefix| path.start_with?(prefix) }
    next false if path == "db/schema.rb" || path.match?(%r{\Adb/[^/]+_schema\.rb\z})
    next false if %w(bin/dev).include?(path)
    next true unless path.start_with?("bin/")

    File.foreach(path).first.to_s.include?("ruby")
  end

paths = ARGV.empty? ? ruby_files : ARGV
issues = []

paths.each do |path|
  raise ArgumentError, "Ruby source file does not exist: #{path}" unless File.file?(path)

  lines = File.readlines(path)
  directive_indices =
    lines.each_index.select do |index|
      lines[index].match?(/^\s*#\s*frozen_string_literal\s*:/)
    end
  shebang = lines.first&.start_with?("#!")
  allowed_indices = shebang ? [1] : [0, 1]
  valid_indices =
    directive_indices.select do |index|
      allowed_indices.include?(index) && lines[0...index].all? do |line|
        line.strip.empty? || line.lstrip.start_with?("#")
      end && lines[index].match?(/^# frozen_string_literal: true\r?\n?$/)
    end

  if directive_indices.empty?
    issues << "#{path}: missing # frozen_string_literal: true"
  elsif directive_indices.length > 1
    issues << "#{path}: duplicate frozen_string_literal directives"
  elsif valid_indices.empty?
    issues << "#{path}: directive must be true and in the leading comment block"
  end

  if lines.any? { |line| line.match?(/^\s*#\s*rubocop:disable\b.*\bStyle\/FrozenStringLiteralComment\b/) }
    issues << "#{path}: inline disable of Style/FrozenStringLiteralComment is prohibited"
  end
end

if issues.empty?
  puts "frozen_string_directive_check_ok=#{paths.length}"
else
  warn issues.join("\n")
  exit 1
end
