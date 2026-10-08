# frozen_string_literal: true

require "prism"

class AvatarLegacyClientIdDetector
  HASH_WRITERS = %i(
    new build create create! create_with_owner update update! update_all update_columns
    assign_attributes attributes= insert insert! insert_all insert_all! upsert upsert_all
    find_or_create_by find_or_create_by! create_or_find_by create_or_find_by!
    find_or_initialize_by
  ).freeze
  ATTRIBUTE_WRITERS = %i[update_column update_attribute update_attribute! write_attribute []=].freeze
  PRINCIPALS = %w(current_client principal actor user client @user @client).freeze

  public

  def offending_lines(source)
    result = Prism.parse(source)
    unless result.success?
      raise ArgumentError, "Cannot inspect Ruby source: #{result.errors.map(&:message).join("; ")}"
    end

    lines = []
    inspect_node(result.value, {}, lines)
    lines.uniq.sort!
  end

  private

  def inspect_node(node, bindings, lines)
    return unless node

    if node.is_a?(Prism::DefNode) || node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)
      node.compact_child_nodes.each { |child| inspect_node(child, {}, lines) }
      return
    end

    if node.is_a?(Prism::LocalVariableWriteNode) || node.is_a?(Prism::InstanceVariableWriteNode)
      inspect_node(node.value, bindings, lines)
      bindings[node.name] = [node.value, bindings.dup]
      return
    end

    if node.is_a?(Prism::CallNode) && avatar_receiver?(node.receiver, bindings)
      lines << node.location.start_line if legacy_write?(node, bindings)
    end

    node.compact_child_nodes.each { |child| inspect_node(child, bindings, lines) }
  end

  def legacy_write?(node, bindings)
    arguments = node.arguments&.arguments || []
    if node.name == :client_id=
      legacy_value?(arguments.first, bindings)
    elsif ATTRIBUTE_WRITERS.include?(node.name)
      client_id_key?(arguments.first) && legacy_value?(arguments[1], bindings)
    elsif HASH_WRITERS.include?(node.name)
      arguments.any? { |argument| legacy_hash?(argument, bindings) }
    else
      false
    end
  end

  def resolve(node, bindings)
    while node.is_a?(Prism::LocalVariableReadNode) || node.is_a?(Prism::InstanceVariableReadNode)
      break unless bindings.key?(node.name)

      node, bindings = bindings.fetch(node.name)
    end
    [node, bindings]
  end

  def avatar_receiver?(node, bindings)
    node, bindings = resolve(node, bindings)
    case node
    when Prism::ConstantReadNode, Prism::ConstantPathNode
      node.name == :Avatar
    when Prism::CallNode
      return true if %i(avatar avatars).include?(node.name)

      avatar_receiver?(node.receiver, bindings)
    else
      # An unresolved receiver may be an Avatar passed into this scope; absence of type
      # evidence cannot authorize the legacy write.
      true
    end
  end

  def legacy_value?(node, bindings)
    node, = resolve(node, bindings)
    return false unless node
    return true if node.location.slice == "legacy_compatibility_client_id"

    node.is_a?(Prism::CallNode) && node.name == :id && node.receiver &&
      PRINCIPALS.include?(node.receiver.location.slice)
  end

  def client_id_key?(node)
    (node.is_a?(Prism::SymbolNode) || node.is_a?(Prism::StringNode)) && node.unescaped == "client_id"
  end

  def legacy_hash?(node, bindings)
    node, bindings = resolve(node, bindings)
    case node
    when Prism::HashNode, Prism::KeywordHashNode
      node.elements.any? do |element|
        if element.is_a?(Prism::AssocNode)
          client_id_key?(element.key) && legacy_value?(element.value, bindings)
        elsif element.is_a?(Prism::AssocSplatNode)
          legacy_hash?(element.value, bindings)
        else
          false
        end
      end
    when Prism::ArrayNode
      node.elements.any? { |element| legacy_hash?(element, bindings) }
    else
      false
    end
  end
end
