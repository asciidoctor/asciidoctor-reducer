# frozen_string_literal: true

require 'asciidoctor'
require_relative 'reducer/preprocessor'
require_relative 'reducer/tree_processor'

Asciidoctor::Extensions.register do
  preprocessor Asciidoctor::Reducer::Preprocessor
  tree_processor Asciidoctor::Reducer::TreeProcessor
end
