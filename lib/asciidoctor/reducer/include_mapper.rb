# frozen_string_literal: true

require_relative 'include_mapper/extension'

Asciidoctor::Extensions.register do
  next if document.options[:reduced]
  tree_processor Asciidoctor::Reducer::IncludeMapper
end
