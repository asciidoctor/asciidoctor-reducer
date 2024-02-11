# frozen_string_literal: true

module Asciidoctor::Reducer
  module ConditionalDirectiveTracker
    def preprocess_conditional_directive keyword, target, delimiter, text
      skip_active = @skipping
      depth = @conditional_stack.size
      directive_lineno = @lineno
      result = super
      return result if @skipping && skip_active
      curr_inc_replacement = @include_replacements.current
      drop = curr_inc_replacement[:drop] ||= []
      adjusted_directive_lineno = directive_lineno - (curr_inc_replacement[:offset] ||= 0)
      if (depth_change = @conditional_stack.size - depth) < 0
        if skip_active
          drop.push(*(drop.pop..adjusted_directive_lineno))
        else
          drop << adjusted_directive_lineno
        end
      elsif depth_change > 0 || directive_lineno == @lineno
        drop << adjusted_directive_lineno
      else
        drop << [adjusted_directive_lineno, text]
      end
      result
    end
  end
end
