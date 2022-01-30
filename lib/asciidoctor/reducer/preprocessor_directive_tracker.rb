# frozen_string_literal: true

module Asciidoctor::Reducer
  module PreprocessorDirectiveTracker
    attr_writer :source_lines
    attr_reader :x_include_replacements

    def self.extended instance
      instance.instance_variable_set :@x_include_replacements, ([{ drop: [] }].extend CurrentPointer)
      instance.instance_variable_set :@x_parents, [0]
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
      @x_push_include_called = false
      inc_lineno = @lineno - 1 # we're currently on the include line, which is 1-based
      result = super
      return result if @x_push_include_called
      parent_depth = (parents = @x_parents).length
      if (depth_change = @include_stack.length - (parent_depth - 1)) < 0
        parent_depth -= (parents.slice! parent_depth + depth_change, -depth_change).length
      end
      inc_lines = ((line = lines[0].to_s).start_with? 'Unresolved directive in ') && (line.end_with? ']') ? [line] : []
      push_include_replacement inc_lines, parent_depth, inc_lineno
      result
    end

    def push_include data, file, path, lineno, attrs
      @x_push_include_called = true
      inc_lineno = @lineno - 2 # we're below the include line, which is 1-based
      prev_inc_depth = @include_stack.length
      # Q: can we do this without resetting the lineno?
      lineno = 1 # rubocop:disable Lint/ShadowedArgument
      super
      parent_depth = (parents = @x_parents).length
      # push_include did not push to the stack
      if (inc_depth = @include_stack.length) == prev_inc_depth
        if (depth_change = inc_depth - (parent_depth - 1)) < 0
          parent_depth -= (parents.slice! parent_depth + depth_change, -depth_change).length
        end
      else
        if (depth_change = inc_depth - parent_depth) > 0
          parents << @x_include_replacements.length.pred
          parent_depth += 1
        elsif depth_change < 0
          parent_depth -= (parents.slice! parent_depth + depth_change, -depth_change).length
        end
        inc_lines = lines
      end
      push_include_replacement inc_lines, parent_depth, inc_lineno
      self
    end

    def pop_include
      @x_include_replacements.current = @x_include_replacements[@x_include_replacements.current[:into] || 0]
      super
    end

    private

    def push_include_replacement inc_lines, parent_depth, inc_lineno
      @x_include_replacements << {
        lines: inc_lines || [],
        drop: [],
        into: @x_parents[parent_depth - 1],
        index: inc_lineno,
        replace: @x_include_directive_line,
      }
      @x_include_replacements.current = @x_include_replacements[-1] if inc_lines
      nil
    end
  end

  module CurrentPointer
    attr_accessor :current

    def self.extended instance
      instance.current = instance[-1]
    end
  end
end
