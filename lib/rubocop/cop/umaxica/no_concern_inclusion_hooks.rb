# typed: false
# frozen_string_literal: true

module RuboCop
  module Cop
    module Umaxica
      # Rejects `included do` / `prepended do` hooks in application code.
      #
      # `ActiveSupport::Concern` supports these hooks, but this repository forbids them: including a
      # module must not silently register callbacks, validations, scopes, associations, attributes or
      # any other framework configuration on the host class. Shared implementation methods in a
      # concern remain allowed - only the implicit host modification is banned.
      #
      # @example
      #   # bad
      #   module Normalizable
      #     extend ActiveSupport::Concern
      #
      #     included do
      #       before_validation :normalize_name
      #     end
      #   end
      #
      #   # good
      #   module Normalizable
      #     def normalize_name
      #     end
      #   end
      #
      #   class User < ApplicationRecord
      #     include Normalizable
      #
      #     before_validation :normalize_name
      #   end
      class NoConcernInclusionHooks < Base
        MSG = "Do not register host behavior with `%<hook>s do`; declare it explicitly in the host class."

        HOOKS = %i(included prepended).freeze

        public

        def on_block(node)
          send_node = node.send_node

          return unless send_node.receiver.nil?
          return unless HOOKS.include?(send_node.method_name)
          return unless send_node.arguments.empty?

          add_offense(send_node, message: format(MSG, hook: send_node.method_name))
        end

        alias on_numblock on_block
        alias on_itblock on_block
      end
    end
  end
end
