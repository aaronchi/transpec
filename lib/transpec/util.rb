# coding: utf-8

module Transpec
  module Util
    EXAMPLE_GROUP_METHODS = %w(
      describe context
      shared_examples shared_context share_examples_for shared_examples_for
    ).map(&:to_sym).freeze

    EXAMPLE_METHODS = %w(
      example it specify
      focus focused fit
      pending xexample xit xspecify
    ).map(&:to_sym).freeze

    HOOK_METHODS = %w(before after around).map(&:to_sym).freeze

    HELPER_METHODS = %w(subject subject! let let!).map(&:to_sym).freeze

    LITERAL_TYPES = %w(
      true false nil
      int float
      str sym regexp
    ).map(&:to_sym).freeze

    WHITESPACES = [' ', "\t"].freeze

    module_function

    def proc_literal?(node)
      return false unless node.type == :block

      send_node = node.children.first
      receiver_node, method_name, *_ = *send_node

      if receiver_node.nil? || const_name(receiver_node) == 'Kernel'
        [:lambda, :proc].include?(method_name)
      elsif const_name(receiver_node) == 'Proc'
        method_name == :new
      else
        false
      end
    end

    def const_name(node)
      return nil if node.nil? || node.type != :const

      const_names = []
      const_node = node

      loop do
        namespace_node, name = *const_node
        const_names << name
        break unless namespace_node
        break unless namespace_node.is_a?(Parser::AST::Node)
        break if namespace_node.type == :cbase
        const_node = namespace_node
      end

      const_names.reverse.join('::')
    end

    def here_document?(node)
      return false unless [:str, :dstr].include?(node.type)
      map = node.loc
      return false if !map.respond_to?(:begin) || map.begin.nil?
      map.begin.source.start_with?('<<')
    end

    def contain_here_document?(node)
      here_document?(node) || node.each_descendent_node.any? { |n| here_document?(n) }
    end

    def in_parentheses?(node)
      return false unless node.type == :begin
      source = node.loc.expression.source
      source[0] == '(' && source[-1] == ')'
    end

    def indentation_of_line(arg)
      line = case arg
             when AST::Node             then arg.loc.expression.source_line
             when Parser::Source::Range then arg.source_line
             when String                then arg
             else fail ArgumentError, "Invalid argument #{arg}"
            end

      /^(?<indentation>\s*)\S/ =~ line
      indentation
    end

    def literal?(node)
      case node.type
      when *LITERAL_TYPES
        true
      when :array, :irange, :erange
        node.children.all? { |n| literal?(n) }
      when :hash
        node.children.all? do |pair_node|
          pair_node.children.all? { |n| literal?(n) }
        end
      else
        false
      end
    end

    def expand_range_to_adjacent_whitespaces(range, direction = :both)
      source = range.source_buffer.source
      begin_pos = if [:both, :begin].include?(direction)
                    find_consecutive_whitespace_position(source, range.begin_pos, :downto)
                  else
                    range.begin_pos
                  end

      end_pos = if [:both, :end].include?(direction)
                  find_consecutive_whitespace_position(source, range.end_pos - 1, :upto) + 1
                else
                  range.end_pos
                end

      Parser::Source::Range.new(range.source_buffer, begin_pos, end_pos)
    end

    def find_consecutive_whitespace_position(source, origin, method)
      from, to = case method
                 when :upto
                   [origin + 1, source.length - 1]
                 when :downto
                   [origin - 1, 0]
                 else
                   fail "Invalid method #{method}"
                 end

      from.send(method, to).reduce(origin) do |previous_position, position|
        character = source[position]
        if WHITESPACES.include?(character)
          position
        else
          return previous_position
        end
      end
    end
  end
end
