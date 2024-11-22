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
        nil
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

    def register registry = nil
      (registry || ::Asciidoctor::Extensions).groups[key] ||= group
    end

    def unregister registry = nil
      (registry || ::Asciidoctor::Extensions).groups.delete key
      nil
    end
  end
end
