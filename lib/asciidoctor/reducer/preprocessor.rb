# frozen_string_literal: true

require_relative 'include_directive_tracker'
require_relative 'conditional_directive_tracker'

module Asciidoctor::Reducer
  class Preprocessor < ::Asciidoctor::Extensions::Preprocessor
    def process doc, reader
      reader.extend IncludeDirectiveTracker
      reader.extend ConditionalDirectiveTracker unless doc.options[:preserve_conditionals]
    end
  end
end
