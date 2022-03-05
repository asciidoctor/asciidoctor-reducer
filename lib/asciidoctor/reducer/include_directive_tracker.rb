# frozen_string_literal: true

module Asciidoctor::Reducer
  module IncludeDirectiveTracker
    attr_reader :include_replacements
    attr_writer :source_lines

    def self.extended instance
      instance.instance_variable_set :@include_replacements, ([{}].extend CurrentPosition)
      instance.instance_variable_set :@x_reducer, {}
    end

    def preprocess_include_directive target, attrlist
      @x_reducer[:include_directive_line] = %(include::#{target}[#{attrlist}])
      @x_reducer[:include_pushed] = false
      inc_lineno = @lineno # we're currently on the include line, which is 1-based
      result = super
      unless @x_reducer[:include_pushed]
        if (ln = peek_line true) && (ln.end_with? ']') && !(unresolved = ln.start_with? 'Unresolved directive in ')
          if inc_lineno == @lineno && (unresolved = ln.start_with? 'link:')
            ln = %(#{ln.slice 0, (ln.length - 1)}role=include])
          end
        end
        push_include_replacement inc_lineno, (unresolved ? [ln] : []), unresolved
      end
      @x_reducer.clear
      result
    end

    def push_include data, file, path, lineno, attrs
      @x_reducer[:include_pushed] = true
      inc_lineno = @lineno - 1 # we're below the include line, which is 1-based
      prev_inc_depth = @include_stack.size
      result = super
      push_include_replacement inc_lineno, (@include_stack.size > prev_inc_depth ? lines : [])
      result
    end

    def pop_include
      @include_replacements.up unless @x_reducer[:include_pushed]
      super
    end

    private

    def push_include_replacement lineno, lines, unresolved = false
      (inc_replacements = @include_replacements) << {
        into: inc_replacements.pointer,
        lineno: lineno,
        line: @x_reducer[:include_directive_line],
        lines: lines,
      }
      inc_replacements.to_end unless unresolved || lines.empty?
      nil
    end
  end

  module CurrentPosition
    attr_reader :pointer

    def self.extended instance
      instance.to_end
    end

    def current
      self[@pointer]
    end

    def to_end
      @pointer = size - 1
    end

    def up
      @pointer = current[:into]
    end
  end

  private_constant :CurrentPosition
end
