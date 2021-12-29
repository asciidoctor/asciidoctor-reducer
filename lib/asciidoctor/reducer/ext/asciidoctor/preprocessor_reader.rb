# frozen_string_literal: true

module Asciidoctor::Reducer
  module AsciidoctorExt
    module PreprocessorReader
      def preprocess_include_directive target, attrlist
        @x_include_directive_line = %(include::#{target}[#{attrlist}])
        @x_push_include_called = false
        inc_lineno = @lineno - 1 # we're currently on the include line, which is 1-based
        result = super
        return result if @x_push_include_called
        parent_depth = (parents = @x_parents).length
        depth_change = @include_stack.length - (parent_depth - 1)
        parent_depth -= (parents.slice! parent_depth + depth_change, -depth_change).length if depth_change < 0
        lines = ((line = @lines[-1].to_s).start_with? 'Unresolved directive in ') && (line.end_with? ']') ? [line] : []
        @x_include_replacements << {
          lines: lines,
          into: parents[parent_depth - 1],
          index: inc_lineno,
          replace: @x_include_directive_line,
        }
      end

      def push_include data, file, path, lineno, attrs
        @x_push_include_called = true
        inc_lineno = @lineno - 2 # we're below the include line, which is 1-based
        prev_inc_depth = @include_stack.length
        # Q: can we do this without resetting the lineno?
        lineno = 1 # rubocop:disable Lint/ShadowedArgument
        super
        inc_depth = @include_stack.length
        parent_depth = (parents = @x_parents).length
        # push_include did not push to the stack
        if inc_depth == prev_inc_depth
          depth_change = inc_depth - (parent_depth - 1)
          parent_depth -= (parents.slice! parent_depth + depth_change, -depth_change).length if depth_change < 0
          @x_include_replacements << {
            lines: [],
            into: parents[parent_depth - 1],
            index: inc_lineno,
            replace: @x_include_directive_line,
          }
        else
          depth_change = inc_depth - parent_depth
          if depth_change > 0
            parents << @x_include_replacements.length.pred
            parent_depth += 1
          elsif depth_change < 0
            parent_depth -= (parents.slice! parent_depth + depth_change, -depth_change).length
          end
          @x_include_replacements << {
            lines: @lines.reverse,
            into: parents[parent_depth - 1],
            index: inc_lineno,
            replace: @x_include_directive_line,
          }
        end
        self
      end
    end
  end
end
