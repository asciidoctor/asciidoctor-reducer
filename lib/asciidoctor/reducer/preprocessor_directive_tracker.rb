# frozen_string_literal: true

module Asciidoctor::Reducer
  module PreprocessorDirectiveTracker
    attr_writer :source_lines
    attr_reader :x_include_replacements

    def self.extended instance
      instance.instance_variable_set :@x_include_replacements, ([{ drop: [] }].extend CurrentPosition)
      instance.instance_variable_set :@x_include_directive_line, nil
      instance.instance_variable_set :@x_include_pushed, nil
    end

    def preprocess_conditional_directive keyword, target, delimiter, text
      return super if @document.options[:preserve_conditionals]
      skip_active = @skipping
      depth = @conditional_stack.length
      cond_lineno = @lineno
      result = super
      return result if @skipping && skip_active
      drop = @x_include_replacements.current[:drop]
      if (depth_change = @conditional_stack.length - depth) < 0
        if skip_active
          drop.push(*(drop.pop..cond_lineno))
        else
          drop << cond_lineno
        end
      elsif depth_change > 0 || cond_lineno == @lineno
        drop << cond_lineno
      else
        drop << [cond_lineno, text]
      end
      result
    end

    def preprocess_include_directive target, attrlist
      @x_include_directive_line = %(include::#{target}[#{attrlist}])
      @x_include_pushed = false
      inc_lineno = @lineno # we're currently on the include line, which is 1-based
      result = super
      unless @x_include_pushed
        if (ln = peek_line true) && (ln.end_with? ']') && !(unresolved = ln.start_with? 'Unresolved directive in ')
          if @document.safe >= ::Asciidoctor::SafeMode::SECURE && inc_lineno == @lineno && (ln.start_with? 'link:')
            ln = (ln.slice 0, (ln.length - 1)) + 'role=include]'
            unresolved = true
          end
        end
        push_include_replacement inc_lineno, (unresolved ? [ln] : []), unresolved
      end
      @x_include_directive_line = @x_include_pushed = nil
      result
    end

    def push_include data, file, path, lineno, attrs
      @x_include_pushed = true
      inc_lineno = @lineno - 1 # we're below the include line, which is 1-based
      prev_inc_depth = @include_stack.length
      result = super
      push_include_replacement inc_lineno, (@include_stack.length > prev_inc_depth ? lines : [])
      result
    end

    def pop_include
      @x_include_replacements.pos = @x_include_replacements.current[:into] unless @x_include_pushed
      super
    end

    private

    def push_include_replacement inc_lineno, inc_lines, unresolved = false
      (inc_replacements = @x_include_replacements) << {
        into: inc_replacements.pos,
        lineno: inc_lineno,
        line: @x_include_directive_line,
        lines: inc_lines,
        drop: [],
      }
      inc_replacements.pos = inc_replacements.length - 1 unless unresolved || inc_lines.empty?
      nil
    end
  end

  module CurrentPosition
    attr_accessor :pos

    def self.extended instance
      instance.pos = instance.length - 1
    end

    def current
      self[@pos]
    end
  end

  private_constant :CurrentPosition
end
