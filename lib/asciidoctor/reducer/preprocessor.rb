# frozen_string_literal: true

require_relative 'ext/asciidoctor/preprocessor_reader'

module Asciidoctor::Reducer
  class Preprocessor < ::Asciidoctor::Extensions::Preprocessor
    def process doc, reader
      return if doc.options[:reduced]
      # Q: is there a better place we can store the original logger?
      ::Asciidoctor::LoggerManager.instance_variable_set :@original_logger, ::Asciidoctor::LoggerManager.logger
      ::Asciidoctor::LoggerManager.logger = ::Asciidoctor::NullLogger.new
      reader.singleton_class.prepend AsciidoctorExt::PreprocessorReader
      reader.instance_variable_set :@x_include_replacements, [{}]
      reader.instance_variable_set :@x_parents, [0]
      nil
    end
  end
end
