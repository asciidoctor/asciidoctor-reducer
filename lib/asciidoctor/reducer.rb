# frozen_string_literal: true

require 'asciidoctor' unless defined? Asciidoctor.load
require_relative 'reducer/extensions'
Asciidoctor::Reducer.autoload :VERSION, (::File.join __dir__, 'reducer', 'version.rb')

Asciidoctor::Extensions.register :reducer do
  next if document.options[:reduced]
  preprocessor Asciidoctor::Reducer::Preprocessor
  tree_processor Asciidoctor::Reducer::TreeProcessor
end
