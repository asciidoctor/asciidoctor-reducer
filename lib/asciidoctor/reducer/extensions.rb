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

    def key
      :reducer
    end

    def prepare_registry registry = nil
      registry = ::Asciidoctor::Extensions.create(&registry) if ::Proc === registry
      return registry if ::Asciidoctor::Extensions.groups[key]
      if registry
        registry.groups[key] = group
        registry
      else
        ::Asciidoctor::Extensions.create key, &group
      end
    end

    def register
      ::Asciidoctor::Extensions.register key, &group
    end

    def unregister
      ::Asciidoctor::Extensions.groups.delete key # NOTE `Extensions.unregister key` fails if groups is not initialized
    end
  end
end
