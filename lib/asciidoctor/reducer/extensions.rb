# frozen_string_literal: true

require 'asciidoctor' unless defined? Asciidoctor.load
require_relative 'preprocessor'
require_relative 'tree_processor'

module Asciidoctor::Reducer
  module Extensions
    module_function

    def group
      proc do
        next if document.options[:reduced]
        preprocessor Preprocessor
        tree_processor TreeProcessor
      end
    end

    def prepare_registry registry = nil
      registry = ::Asciidoctor::Extensions.create(&registry) if ::Proc === registry
      unless ::Asciidoctor::Extensions.groups[:reducer]
        if registry
          registry.groups[:reducer] = group
        else
          registry = ::Asciidoctor::Extensions.create :reducer, &group
        end
      end
      registry
    end

    def register
      ::Asciidoctor::Extensions.register :reducer, &group
    end

    def unregister
      ::Asciidoctor::Extensions.unregister :reducer
    end
  end
end
