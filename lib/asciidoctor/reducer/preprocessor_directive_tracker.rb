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
      return super if (opts = @document.options)[:preserve_conditionals] || opts[:reduced]
      skip_active = @skipping
      depth = @conditional_stack.length
      cond_lineno = @lineno - 1
      result = super
      return result if @skipping && skip_active
      drop = @x_include_replacements.current[:drop]
      if (depth_change = @conditional_stack.length - depth) < 0
        if skip_active
          drop.push(*(drop.pop..cond_lineno))
        else
          drop << cond_lineno
        end
      elsif depth_change > 0 || cond_lineno == @lineno - 1
        drop << cond_lineno
      else
        drop << [cond_lineno, text]
      end
      result
    end

    def preprocess_include_directive target, attrlist
      @x_include_directive_line = %(include::#{target}[#{attrlist}])
      @x_include_pushed = false
      inc_lineno = @lineno - 1 # we're currently on the include line, which is 1-based
      result = super
      unless @x_include_pushed
        inc_lines = ((line = lines[0].to_s).start_with? 'Unresolved directive in ') && (line.end_with? ']') ? [line] : []
        push_include_replacement inc_lineno, inc_lines
      end
      @x_include_directive_line = @x_include_pushed = nil
      result
    end

    def push_include data, file, path, lineno, attrs
      @x_include_pushed = true
      inc_lineno = @lineno - 2 # we're below the include line, which is 1-based
      prev_inc_depth = @include_stack.length
      result = super
      push_include_replacement inc_lineno, (@include_stack.length > prev_inc_depth ? lines : nil)
      result
    end

    def pop_include
      @x_include_replacements.pos = @x_include_replacements.current[:into] unless @x_include_pushed
      super
    end

    private

    def push_include_replacement inc_lineno, inc_lines
      @x_include_replacements << {
        into: @x_include_replacements.pos,
        lineno: inc_lineno,
        line: @x_include_directive_line,
        lines: inc_lines || [],
        drop: [],
      }
      @x_include_replacements.pos = @x_include_replacements.length - 1 if inc_lines
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
end
