# frozen_string_literal: true

module Asciidoctor::Reducer
  module IncludeDirectiveTracker
    def self.extended instance
      instance.singleton_class.send :attr_reader, :include_replacements
      instance.instance_variable_set :@include_replacements, ([{}].extend CurrentPosition)
      instance.instance_variable_set :@x_reducer, {}
    end

    def preprocess_include_directive target, attrlist
      @x_reducer[:include_directive_line] = %(include::#{target}[#{attrlist}])
      @x_reducer[:include_pushed] = false
      directive_lineno = @lineno # we're currently on the include line, which is 1-based
      result = super
      unless @x_reducer[:include_pushed]
        if ((ln = peek_line true)&.end_with? ']') && !(unresolved = ln.start_with? 'Unresolved directive in ') &&
            directive_lineno == @lineno && (unresolved = ln.start_with? 'link:') && !(ln.include? '[role=')
          ln = ln.sub '[', %([role=include#{ln[-2] == '[' ? '' : ','})
        end
        push_include_replacement directive_lineno, (unresolved ? [ln] : []), 0, unresolved
      end
      @x_reducer.clear
      result
    end

    def push_include data, file, path, lineno, attrs
      @x_reducer[:include_pushed] = true
      directive_lineno = @lineno - 1 # we're below the include line, which is 1-based
      prev_inc_depth = @include_stack.size
      offset = lineno > 1 ? lineno - 1 : 0
      result = super
      if @include_stack.size > prev_inc_depth
        inc_lines = lines
        offset -= 2 if (attrs.key? 'leveloffset') && (inc_lines[0].start_with? ':leveloffset: ') && inc_lines[1]&.empty?
      end
      push_include_replacement directive_lineno, inc_lines || [], offset
      result
    end

    private

    def pop_include
      @include_replacements.up unless @x_reducer[:include_pushed]
      super
    end

    def push_include_replacement lineno, lines, offset, unresolved = false
      (inc_replacements = @include_replacements) << {
        into: inc_replacements.pointer,
        lineno: lineno - (inc_replacements.current[:offset] ||= 0),
        line: @x_reducer[:include_directive_line],
        lines: lines,
        offset: offset,
      }
      inc_replacements.to_end unless unresolved || lines.empty?
      nil
    end
  end

  module CurrentPosition
    def self.extended instance
      instance.singleton_class.send :attr_reader, :pointer
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
