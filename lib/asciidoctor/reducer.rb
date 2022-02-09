# frozen_string_literal: true

require 'asciidoctor'
require_relative 'reducer/extensions'

Asciidoctor::Extensions.register :reducer do
  next if document.options[:reduced]
  preprocessor Asciidoctor::Reducer::Preprocessor
  tree_processor Asciidoctor::Reducer::TreeProcessor
end
