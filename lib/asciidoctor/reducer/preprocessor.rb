# frozen_string_literal: true

require_relative 'preprocessor_directive_tracker'

module Asciidoctor::Reducer
  class Preprocessor < ::Asciidoctor::Extensions::Preprocessor
    def process doc, reader
      return if doc.options[:reduced]
      reader.singleton_class.prepend PreprocessorDirectiveTracker
      reader.instance_variable_set :@x_include_replacements, ([{ drop: [] }].extend Current)
      reader.instance_variable_set :@x_parents, [0]
      nil
    end
  end

  module Current
    attr_accessor :current

    def self.extended obj
      obj.current = obj[-1]
    end
  end
end
