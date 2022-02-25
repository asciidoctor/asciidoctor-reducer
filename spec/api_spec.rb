# frozen_string_literal: true

require_relative 'spec_helper'

describe Asciidoctor::Reducer do
  it 'should provide VERSION constant' do
    (expect described_class::VERSION).to match %r/^\d+\.\d+\.\d+(\.\S+)?$/
  end

  describe '.reduce' do
    subject { described_class.method :reduce }

    it 'should reduce input when no options are specified' do
      the_source = File.read (fixture_file 'preprocessor-conditional.adoc'), mode: 'r:UTF-8'
      expected = 'primary content'
      doc = subject.call the_source
      (expect doc.source).to eql expected
    end

    it 'should reduce input specified as File object' do
      source_file = fixture_file 'parent-with-single-include.adoc'
      expected_lines = <<~'EOS'.chomp.split ?\n
      before include

      no includes here

      just good old-fashioned paragraph text

      after include
      EOS
      doc = File.open(source_file, mode: 'r:UTF-8') {|f| subject.call f }
      (expect doc.source_lines).to eql expected_lines
      (expect doc.attr 'docname').to eql 'parent-with-single-include'
      (expect doc.attr 'docfile').to eql source_file
      (expect doc.attr 'docdir').to eql (File.dirname source_file)
    end
  end

  describe '.reduce_file' do
    subject { described_class.method :reduce_file }

    it 'should reduce input when no options are specified' do
      the_source_file = fixture_file 'preprocessor-conditional.adoc'
      expected = 'primary content'
      doc = subject.call the_source_file
      (expect doc.source).to eql expected
    end
  end

  describe '#write' do
    it 'should reduce input to file at path specified by :to option' do
      the_source_file = fixture_file 'parent-with-include-with-single-line-paragraph.adoc'
      expected = <<~'EOS'.chomp
      before include

      single line paragraph

      after include
      EOS
      with_tmp_file do |the_output_file|
        subject.reduce_file the_source_file, to: the_output_file.path
        output_contents = the_output_file.read
        (expect output_contents).to eql (expected + ?\n)
      end
    end

    it 'should reduce input to file for Pathname specified by :to option' do
      the_source_file = fixture_file 'parent-with-include-with-single-line-paragraph.adoc'
      expected = <<~'EOS'.chomp
      before include

      single line paragraph

      after include
      EOS
      with_tmp_file do |the_output_file|
        the_output_pathname = ::Pathname.new the_output_file.path
        subject.reduce_file the_source_file, to: the_output_pathname
        output_contents = the_output_file.read
        (expect output_contents).to eql (expected + ?\n)
      end
    end

    it 'should reduce input to string if :to option is String' do
      the_source_file = fixture_file 'parent-with-include-with-single-line-paragraph.adoc'
      expected = <<~'EOS'.chomp
      before include

      single line paragraph

      after include
      EOS
      result = subject.reduce_file the_source_file, to: String
      (expect result).to eql expected
    end

    it 'should reduce input and send to write method if :to option is IO' do
      the_source_file = fixture_file 'parent-with-include-with-single-line-paragraph.adoc'
      expected = <<~'EOS'.chomp
      before include

      single line paragraph

      after include
      EOS
      to = StringIO.new
      subject.reduce_file the_source_file, to: to
      (expect to.string).to eql (expected + ?\n)
    end

    it 'should reduce input and send to write method if :to option value responds to write' do
      the_source_file = fixture_file 'parent-with-include-with-single-line-paragraph.adoc'
      expected = <<~'EOS'.chomp
      before include

      single line paragraph

      after include
      EOS
      to = (Class.new do
        attr_reader :string

        def initialize
          @string = nil
        end

        def write string
          @string = string
        end
      end).new
      subject.reduce_file the_source_file, to: to
      (expect to.string).to eql (expected + ?\n)
    end

    it 'should reduce input but not write if :to option is /dev/null' do
      the_source_file = fixture_file 'parent-with-include-with-single-line-paragraph.adoc'
      expected = <<~'EOS'.chomp
      before include

      single line paragraph

      after include
      EOS
      result = subject.reduce_file the_source_file, to: '/dev/null'
      (expect result.source).to eql expected
    end

    it 'should reduce input but not write if :to option is nil' do
      the_source_file = fixture_file 'parent-with-include-with-single-line-paragraph.adoc'
      expected = <<~'EOS'.chomp
      before include

      single line paragraph

      after include
      EOS
      result = subject.reduce_file the_source_file, to: nil
      (expect result.source).to eql expected
    end
  end

  describe 'extension registry' do
    it 'should not register extension for call if extension is registered globally' do
      described_class::Extensions.register
      calls = 0
      result = subject.reduce_file (fixture_file 'parent-with-single-include.adoc'), sourcemap: true,
        extensions: proc {
          tree_processor do
            prefer
            process do
              calls += 1
              nil
            end
          end
        }
      expected_lines = <<~'EOS'.chomp.split ?\n
      before include

      no includes here

      just good old-fashioned paragraph text

      after include
      EOS
      (expect calls).to eql 2
      (expect result.source_lines).to eql expected_lines
    ensure
      described_class::Extensions.unregister
    end
  end
end
