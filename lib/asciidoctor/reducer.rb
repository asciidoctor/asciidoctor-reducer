# frozen_string_literal: true

require 'asciidoctor'
require_relative 'reducer/extensions'
require_relative 'reducer/version'

Asciidoctor::Extensions.register :reducer do
  next if document.options[:reduced]
  preprocessor Asciidoctor::Reducer::Preprocessor
  tree_processor Asciidoctor::Reducer::TreeProcessor
end
