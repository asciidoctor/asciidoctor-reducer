# frozen_string_literal: true

require_relative 'preprocessor_directive_tracker'

module Asciidoctor::Reducer
  class Preprocessor < ::Asciidoctor::Extensions::Preprocessor
    def process doc, reader
      doc.options[:reduced] ? reader : (reader.extend PreprocessorDirectiveTracker)
    end
  end
end
