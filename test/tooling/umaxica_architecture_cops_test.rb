# typed: false
# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/test_case"
require "rubocop"
require_relative "../../lib/rubocop/cop/umaxica/no_concern_inclusion_hooks"
require_relative "../../lib/rubocop/cop/umaxica/explicit_method_visibility"

# Self-tests for the architecture cops. They prove the rules reject the patterns the policy in
# docs/architecture/method-visibility-and-concerns.md forbids and accept the ones it requires.
class UmaxicaArchitectureCopsTest < ActiveSupport::TestCase
  def test_included_hook_is_rejected
    offenses = investigate(RuboCop::Cop::Umaxica::NoConcernInclusionHooks, <<~RUBY)
      module Foo
        extend ActiveSupport::Concern

        included do
          before_validation :normalize
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_includes offenses.first.message, "included do"
  end

  def test_prepended_hook_is_rejected
    offenses = investigate(RuboCop::Cop::Umaxica::NoConcernInclusionHooks, <<~RUBY)
      module Foo
        extend ActiveSupport::Concern

        prepended do
          attribute :name
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_includes offenses.first.message, "prepended do"
  end

  def test_concern_without_hooks_is_accepted
    offenses = investigate(RuboCop::Cop::Umaxica::NoConcernInclusionHooks, <<~RUBY)
      module Foo
        extend ActiveSupport::Concern

        def normalize
        end
      end
    RUBY

    assert_empty offenses
  end

  def test_hook_call_with_a_receiver_is_not_a_concern_hook
    offenses = investigate(RuboCop::Cop::Umaxica::NoConcernInclusionHooks, <<~RUBY)
      report.included do |row|
        row
      end
    RUBY

    assert_empty offenses
  end

  def test_implicitly_public_methods_are_rejected
    offenses = investigate(RuboCop::Cop::Umaxica::ExplicitMethodVisibility, <<~RUBY)
      class ImportService
        def call
        end

        def normalize
        end
      end
    RUBY

    assert_equal %w(call normalize), offenses.map { |offense| offense.message[/`(.+?)`/, 1] }
  end

  def test_explicit_sections_are_accepted
    offenses = investigate(RuboCop::Cop::Umaxica::ExplicitMethodVisibility, <<~RUBY)
      class ImportService
        public

        def call
        end

        protected

        def extension_point
        end

        private

        def helper
        end
      end
    RUBY

    assert_empty offenses
  end

  def test_methods_before_the_first_section_are_rejected
    offenses = investigate(RuboCop::Cop::Umaxica::ExplicitMethodVisibility, <<~RUBY)
      class ImportService
        def call
        end

        private

        def helper
        end
      end
    RUBY

    assert_equal %w(call), offenses.map { |offense| offense.message[/`(.+?)`/, 1] }
  end

  def test_inline_and_listed_declarations_are_accepted
    offenses = investigate(RuboCop::Cop::Umaxica::ExplicitMethodVisibility, <<~RUBY)
      class ImportService
        def call
        end

        private def helper
        end

        def peer_compare
        end

        public :call
        protected :peer_compare
      end
    RUBY

    assert_empty offenses
  end

  def test_initialize_is_not_reported
    offenses = investigate(RuboCop::Cop::Umaxica::ExplicitMethodVisibility, <<~RUBY)
      class ImportService
        def initialize(source)
          @source = source
        end

        public

        def call
        end
      end
    RUBY

    assert_empty offenses
  end

  def test_singleton_class_body_sections_are_tracked
    offenses = investigate(RuboCop::Cop::Umaxica::ExplicitMethodVisibility, <<~RUBY)
      class ImportService
        class << self
          public

          def build
          end

          private

          def normalize_options
          end
        end
      end
    RUBY

    assert_empty offenses
  end

  def test_singleton_class_body_without_a_section_is_rejected
    offenses = investigate(RuboCop::Cop::Umaxica::ExplicitMethodVisibility, <<~RUBY)
      class ImportService
        class << self
          def build
          end
        end
      end
    RUBY

    assert_equal %w(build), offenses.map { |offense| offense.message[/`(.+?)`/, 1] }
  end

  def test_def_self_requires_a_class_method_declaration
    rejected = investigate(RuboCop::Cop::Umaxica::ExplicitMethodVisibility, <<~RUBY)
      class ImportService
        def self.build
        end
      end
    RUBY
    accepted = investigate(RuboCop::Cop::Umaxica::ExplicitMethodVisibility, <<~RUBY)
      class ImportService
        def self.build
        end

        def self.normalize_options
        end

        public_class_method :build
        private_class_method :normalize_options
      end
    RUBY

    assert_equal %w(build), rejected.map { |offense| offense.message[/`(.+?)`/, 1] }
    assert_empty accepted
  end

  def test_module_function_counts_as_an_explicit_section
    offenses = investigate(RuboCop::Cop::Umaxica::ExplicitMethodVisibility, <<~RUBY)
      module Formatting
        module_function

        def format_name(name)
          name
        end
      end
    RUBY

    assert_empty offenses
  end

  def test_methods_defined_by_blocks_and_metaprogramming_are_out_of_scope
    offenses = investigate(RuboCop::Cop::Umaxica::ExplicitMethodVisibility, <<~RUBY)
      class Report
        define_method(:total) do
        end

        [1, 2].each do |index|
          def dynamic
          end
        end

        public

        def call
        end
      end
    RUBY

    assert_empty offenses
  end

  private

  def investigate(cop_class, source, path: "app/services/example.rb")
    cop = cop_class.new(RuboCop::Config.new({}, "#{Dir.pwd}/.rubocop.yml"))
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
    commissioner = RuboCop::Cop::Commissioner.new([cop], [], raise_error: true)

    commissioner.investigate(processed_source).offenses.sort_by { |offense| offense.location.line }
  end
end
