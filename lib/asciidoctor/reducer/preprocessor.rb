# frozen_string_literal: true

require_relative 'preprocessor_directive_tracker'

module Asciidoctor::Reducer
  class Preprocessor < ::Asciidoctor::Extensions::Preprocessor
    def process _, reader
      reader.extend PreprocessorDirectiveTracker
    end
  end
end
