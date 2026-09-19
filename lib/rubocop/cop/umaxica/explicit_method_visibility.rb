# typed: false
# frozen_string_literal: true

module RuboCop
  module Cop
    module Umaxica
      # Requires application-defined methods to sit under an explicit visibility declaration.
      #
      # Ruby defaults to `public`, so a public method is normally an accident of syntax rather than a
      # design decision. This cop only accepts a method whose visibility was declared: a bare
      # `public` / `protected` / `private` (or `module_function`) section, an inline
      # `private def ...` form, or a name listed in `public :foo` / `protected :foo` / `private :foo`
      # / `public_class_method :foo` / `private_class_method :foo`.
      #
      # Only methods defined directly in a class, module or `class << self` body are checked. Methods
      # produced by blocks and metaprogramming (`define_method`, `class_eval`, Rails DSL blocks) are
      # out of scope: their visibility is not expressible with a lexical modifier.
      #
      # @example
      #   # bad
      #   class ImportService
      #     def call
      #     end
      #   end
      #
      #   # good
      #   class ImportService
      #     public
      #
      #     def call
      #     end
      #
      #     private
      #
      #     def normalize
      #     end
      #   end
      class ExplicitMethodVisibility < Base
        MSG = "Declare `%<name>s` under an explicit `public`, `protected` or `private` visibility."

        SECTION_MODIFIERS = %i(public protected private module_function).freeze
        INSTANCE_DECLARATIONS = %i(public protected private module_function).freeze
        SINGLETON_DECLARATIONS = %i(public_class_method private_class_method).freeze
        # Ruby already makes these private; their visibility is not an accident of the default.
        IMPLICITLY_PRIVATE = %i(initialize initialize_copy initialize_clone initialize_dup).freeze

        public

        def on_class(node)
          check_body(node.body)
        end

        def on_module(node)
          check_body(node.body)
        end

        def on_sclass(node)
          check_body(node.body)
        end

        private

        def check_body(body)
          return if body.nil?

          statements = body.begin_type? ? body.children : [body]
          instance_declared = declared_names(statements, INSTANCE_DECLARATIONS)
          singleton_declared = declared_names(statements, SINGLETON_DECLARATIONS)
          section_open = false

          statements.each do |statement|
            next unless statement.is_a?(RuboCop::AST::Node)

            if section_modifier?(statement)
              section_open = true
            elsif statement.def_type?
              next if IMPLICITLY_PRIVATE.include?(statement.method_name)

              register(statement) unless section_open || instance_declared.include?(statement.method_name)
            elsif statement.defs_type?
              register(statement) unless singleton_declared.include?(statement.method_name)
            end
          end
        end

        def section_modifier?(node)
          node.send_type? &&
            node.receiver.nil? &&
            node.arguments.empty? &&
            SECTION_MODIFIERS.include?(node.method_name)
        end

        def declared_names(statements, modifiers)
          statements.flat_map { |statement|
            next [] unless statement.is_a?(RuboCop::AST::Node)
            next [] unless statement.send_type?
            next [] unless statement.receiver.nil?
            next [] unless modifiers.include?(statement.method_name)

            statement.arguments.filter_map { |argument|
              case argument.type
              when :sym, :str then argument.value.to_sym
              when :def, :defs then argument.method_name
              end
            }
          }.to_set
        end

        def register(node)
          add_offense(
            node.loc.keyword.join(node.loc.name),
            message: format(MSG, name: node.method_name),
          )
        end
      end
    end
  end
end
