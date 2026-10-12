# frozen_string_literal: true

require "test_helper"
require "prism"

class IdentifierGenerationInvariantTest < ActiveSupport::TestCase
  test "direct production Nanoid generation stays in the shared public identity mechanism" do
    callers = []
    Rails.root.glob("app/**/*.rb").each do |path|
      nodes = [Prism.parse_file(path.to_s).value]
      until nodes.empty?
        node = nodes.pop
        nodes.concat(node.compact_child_nodes)
        next unless node.is_a?(Prism::CallNode) && node.name == :generate
        next unless node.receiver && %w(Nanoid ::Nanoid).include?(node.receiver.slice)

        callers << path.relative_path_from(Rails.root).to_s
      end
    end

    assert_equal ["app/models/concerns/public_id.rb"], callers.sort
  end
end
