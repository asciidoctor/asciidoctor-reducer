# frozen_string_literal: true

require_relative 'spec_helper'
require 'asciidoctor/reducer/cli'

describe Asciidoctor::Reducer::Cli do
  # NOTE override subject to return class object; RSpec returns instance of class by default
  subject { described_class }

  before do
    @old_stdin, $stdin = $stdin, StringIO.new
    @old_stdout, $stdout = $stdout, StringIO.new # rubocop:disable RSpec/ExpectOutput
    @old_stderr, $stderr = $stderr, StringIO.new # rubocop:disable RSpec/ExpectOutput
  end

  after do
    $stdin, $stdout, $stderr = @old_stdin, @old_stdout, @old_stderr # rubocop:disable RSpec/InstanceVariable,RSpec/ExpectOutput
  end

  context 'packaging' do
    it 'should install bin script named asciidoctor-reducer' do
      bin_script = (Pathname.new Gem.bindir) / 'asciidoctor-reducer'
      bin_script = Pathname.new Gem.bin_path 'asciidoctor-reducer', 'asciidoctor-reducer' unless bin_script.exist?
      (expect bin_script).to exist
    end
  end

  context 'options' do
    it 'should display error message and return non-zero exit status when invalid option is specified' do
      (expect subject.run %w(--invalid)).to eql 1
      (expect $stderr.string.chomp).to eql 'asciidoctor-reducer: invalid option: --invalid'
      (expect $stdout.string.chomp).to start_with 'Usage: asciidoctor-reducer'
    end

    it 'should display program name and version when -v option is specified' do
      (expect subject.run %w(-v)).to eql 0
      (expect $stdout.string.chomp).to eql %(asciidoctor-reducer #{Asciidoctor::Reducer::VERSION})
    end

    it 'should ignore other options when -v option is specified' do
      (expect subject.run %w(-v -h)).to eql 0
      (expect $stdout.string.chomp).to eql %(asciidoctor-reducer #{Asciidoctor::Reducer::VERSION})
    end

    it 'should display help text when -h option is specified' do
      (expect subject.run %w(-h)).to eql 0
      stdout = $stdout.string.chomp
      (expect stdout).to start_with 'Usage: asciidoctor-reducer'
      (expect stdout).to include 'Reduces a composite AsciiDoc document'
      (expect stdout).to include '-h, --help'
    end

    it 'should write output to file specified by the -o option' do
      the_source_file = fixture_file 'parent-with-single-include.adoc'
      with_tmp_file do |the_output_file|
        (expect subject.run ['-o', the_output_file.path, the_source_file]).to eql 0
        output_contents = the_output_file.read.chomp
        (expect output_contents).not_to include 'include::'
        (expect output_contents).to include 'just good old-fashioned paragraph text'
      end
    end

    it 'should write to stdout when -o option is -' do
      the_source_file = fixture_file 'parent-with-single-include.adoc'
      (expect subject.run [the_source_file, '-o', '-']).to eql 0
      (expect $stdout.string.chomp).to include 'just good old-fashioned paragraph text'
    end

    it 'should allow runtime attribute to be specified using -a option' do
      the_source_file = fixture_file 'parent-with-include-with-attribute-reference-in-target.adoc'
      expected = <<~'EOS'.chomp
      = Book Title

      == Chapter One

      content
      EOS
      (expect subject.run [the_source_file, '-a', 'chaptersdir=chapters', '-a', 'doctitle=Untitled']).to eql 0
      (expect $stdout.string.chomp).to eql expected
    end

    it 'should set attribute value to empty string if only name is passed to -a option' do
      the_source_file = fixture_file 'preprocessor-conditional.adoc'
      expected = <<~'EOS'.chomp
      primary content
      conditional content
      EOS
      (expect subject.run [the_source_file, '-a', 'flag']).to eql 0
      (expect $stdout.string.chomp).to eql expected
    end

    it 'should reduce preprocessor conditionals by default' do
      the_source_file = fixture_file 'parent-with-single-line-preprocessor-conditional.adoc'
      expected = <<~'EOS'.chomp
      text
      EOS
      (expect subject.run [the_source_file]).to eql 0
      (expect $stdout.string.chomp).to eql expected
    end

    it 'should preserve preprocessor conditionals if --preserve-conditionals option is specified' do
      the_source_file = fixture_file 'parent-with-single-line-preprocessor-conditional.adoc'
      expected = <<~'EOS'.chomp
      ifdef::asciidoctor-version[text]
      EOS
      (expect subject.run [the_source_file, '--preserve-conditionals']).to eql 0
      (expect $stdout.string.chomp).to eql expected
    end

    it 'should set level on logger to higher value specified by --log-level option' do
      the_source_file = fixture_file 'parent-with-unresolved-include.adoc'
      expected = <<~'EOS'.chomp
      before include

      Unresolved directive in parent-with-unresolved-include.adoc - include::no-such-file.adoc[]

      after include
      EOS
      (expect subject.run [the_source_file, '--log-level', 'fatal']).to eql 0
      (expect $stderr.string.chomp).to be_empty
      (expect $stdout.string.chomp).to eql expected
    end

    it 'should ignore --log-level option if value is warn' do
      the_source_file = fixture_file 'parent-with-optional-unresolved-include.adoc'
      expected = <<~'EOS'.chomp
      before include


      after include
      EOS
      (expect subject.run [the_source_file, '--log-level', 'warn']).to eql 0
      (expect $stderr.string.chomp).to be_empty
      (expect $stdout.string.chomp).to eql expected
    end

    it 'should set level on logger to lower value specified by --log-level option' do
      the_source_file = fixture_file 'parent-with-optional-unresolved-include.adoc'
      expected = <<~'EOS'.chomp
      before include


      after include
      EOS
      (expect subject.run [the_source_file, '--log-level', 'info']).to eql 0
      (expect $stderr.string.chomp).to include 'optional include dropped'
      (expect $stdout.string.chomp).to eql expected
    end

    it 'should suppress log messages when -q option is specified' do
      the_source_file = fixture_file 'parent-with-unresolved-include.adoc'
      expected = <<~'EOS'.chomp
      before include

      Unresolved directive in parent-with-unresolved-include.adoc - include::no-such-file.adoc[]

      after include
      EOS
      (expect subject.run [the_source_file, '-q']).to eql 0
      (expect $stderr.string.chomp).to be_empty
      (expect $stdout.string.chomp).to eql expected
    end
  end

  context 'arguments' do
    it 'should show error message and usage and return non-zero exit status when no arguments are given' do
      expected = 'asciidoctor-reducer: Please specify an AsciiDoc file to reduce.'
      (expect subject.run []).to eql 1
      (expect $stderr.string.chomp).to eql expected
      (expect $stdout.string.chomp).to start_with 'Usage: asciidoctor-reducer'
    end

    it 'should show error message and usage and return non-zero exit status when more than one argument is given' do
      expected = 'asciidoctor-reducer: extra arguments detected (unparsed arguments: bar.adoc)'
      (expect subject.run %w(foo.adoc bar.adoc)).to eql 1
      (expect $stderr.string.chomp).to eql expected
      (expect $stdout.string.chomp).to start_with 'Usage: asciidoctor-reducer'
    end

    it 'should write to stdout when -o option is not specified' do
      the_source_file = fixture_file 'parent-with-single-include.adoc'
      (expect subject.run [the_source_file]).to eql 0
      (expect $stdout.string.chomp).to include 'just good old-fashioned paragraph text'
    end

    it 'should read from stdin when argument is -' do
      $stdin.puts %(include::#{fixture_file 'no-includes.adoc'}[])
      $stdin.rewind
      (expect subject.run %w(-)).to eql 0
      (expect $stdout.string.chomp).to include 'just good old-fashioned paragraph text'
    end
  end
end
