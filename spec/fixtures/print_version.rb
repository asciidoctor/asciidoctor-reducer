# frozen_string_literal: true

require 'asciidoctor'
require 'asciidoctor/reducer/api'

puts Asciidoctor::Reducer::VERSION
puts (defined? Asciidoctor::Reducer.reduce_file) && 'loaded'
