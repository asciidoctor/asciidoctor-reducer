# frozen_string_literal: true

DeepCover.configure do
  output 'coverage/report-deep-cover'
  paths %w(lib)
  exclude_paths %w(lib/asciidoctor/reducer/version.rb)
  reporter :text if ENV['CI']
end
