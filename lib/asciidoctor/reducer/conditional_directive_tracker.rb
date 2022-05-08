# frozen_string_literal: true

module Asciidoctor::Reducer
  module ConditionalDirectiveTracker
    def preprocess_conditional_directive keyword, target, delimiter, text
      skip_active = @skipping
      depth = @conditional_stack.size
      directive_lineno = @lineno
      result = super
      return result if @skipping && skip_active
      drop = @include_replacements.current[:drop] ||= []
      if (depth_change = @conditional_stack.size - depth) < 0
        if skip_active
          drop.push(*(drop.pop..directive_lineno))
        else
          drop << directive_lineno
        end
      elsif depth_change > 0 || directive_lineno == @lineno
        drop << directive_lineno
      else
        drop << [directive_lineno, text]
      end
      result
    end
  end
end
