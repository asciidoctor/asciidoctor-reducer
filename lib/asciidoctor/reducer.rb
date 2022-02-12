# frozen_string_literal: true

require 'asciidoctor' unless defined? Asciidoctor.load
require_relative 'reducer/extensions'
require_relative 'reducer/version'

Asciidoctor::Extensions.register :reducer do
  next if document.options[:reduced]
  preprocessor Asciidoctor::Reducer::Preprocessor
  tree_processor Asciidoctor::Reducer::TreeProcessor
end
