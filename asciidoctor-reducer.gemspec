begin
  require_relative 'lib/asciidoctor/reducer/version'
rescue LoadError
  require 'asciidoctor/reducer/version'
end

Gem::Specification.new do |s|
  s.name = 'asciidoctor-reducer'
  s.version = Asciidoctor::Reducer::VERSION
  s.summary = 'Reduces an AsciiDoc document containing includes and conditionals to a single AsciiDoc document.'
  s.description = 'A tool that reduces an AsciiDoc document containing preprocessor directives (includes and conditionals) to a single AsciiDoc document by expanding all includes and evaluating all conditionals.'
  s.authors = ['Dan Allen']
  s.email = 'dan.j.allen@gmail.com'
  s.homepage = 'https://asciidoctor.org'
  s.license = 'MIT'
  # NOTE required ruby version is informational only; it's not enforced since it can't be overridden and can cause builds to break
  #s.required_ruby_version = '>= 2.7.0'
  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/asciidoctor/asciidoctor-reducer/issues',
    'changelog_uri' => 'https://github.com/asciidoctor/asciidoctor-reducer/blob/main/CHANGELOG.adoc',
    'mailing_list_uri' => 'https://chat.asciidoctor.org',
    'source_code_uri' => 'https://github.com/asciidoctor/asciidoctor-reducer'
  }

  # NOTE the logic to build the list of files is designed to produce a usable package even when the git command is not available
  begin
    files = (result = `git ls-files -z`.split ?\0).empty? ? Dir['**/*'] : result
  rescue
    files = Dir['**/*']
  end
  s.files = files.grep %r/^(?:lib\/.+|LICENSE|(?:CHANGELOG|README)\.adoc|#{s.name}\.gemspec)$/
  s.executables = (files.grep %r/^bin\//).map {|f| File.basename f }
  s.require_paths = ['lib']

  s.add_runtime_dependency 'asciidoctor', '~> 2.0'

  s.add_development_dependency 'rake', '~> 13.1.0'
  s.add_development_dependency 'rspec', '~> 3.13.0'
end
