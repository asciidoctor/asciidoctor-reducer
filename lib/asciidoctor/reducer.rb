# frozen_string_literal: true

require 'asciidoctor'
require_relative 'reducer/extensions'

Asciidoctor::Extensions.register :reducer do
  preprocessor Asciidoctor::Reducer::Preprocessor
  tree_processor Asciidoctor::Reducer::TreeProcessor
end
