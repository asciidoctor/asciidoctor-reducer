# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::Reducer' do
  it 'should provide VERSION constant' do
    (expect Asciidoctor::Reducer::VERSION).to match %r/^\d+\.\d+\.\d+(\.\S+)?$/
  end

  it 'should be able to require library from Ruby process' do
    script_file = fixture_file 'print_version.rb'
    output = %x(#{ruby} #{Shellwords.escape script_file}).chomp
    (expect output).to eql Asciidoctor::Reducer::VERSION
  end

  it 'should be able to require library using the alias asciidoctor-reducer' do
    (expect require 'asciidoctor-reducer').not_to be_nil
  end

  it 'should load document with no includes' do
    source_file = fixture_file 'parent-with-no-includes.adoc'
    doc = Asciidoctor.load_file source_file, safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    no includes to be found here

    not a one
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect doc.options[:reduced]).to be_falsy
    # NOTE for now, sourcemap is enabled implicitly
    (expect doc.sourcemap).to be true
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
    (expect doc.attr 'docname').to eql 'parent-with-no-includes'
    (expect doc.attr 'docfile').to eql source_file
    (expect doc.attr 'docdir').to eql (File.dirname source_file)
  end

  it 'should resolve top-level include with no nested includes' do
    source_file = fixture_file 'parent-with-single-include.adoc'
    doc = Asciidoctor.load_file source_file, safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    no includes here

    just good old-fashioned paragraph text

    after include
    EOS
    (expect doc.options[:reduced]).to be true
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 4
    (expect doc.sourcemap).to be true
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
    (expect (doc.blocks.map {|it| it.file }).uniq).to eql [source_file]
    (expect doc.attr 'docname').to eql 'parent-with-single-include'
    (expect doc.attr 'docfile').to eql source_file
    (expect doc.attr 'docdir').to eql (File.dirname source_file)
  end

  it 'should resolve top-level include with nested include' do
    source_file = fixture_file 'parent-with-single-include-with-include.adoc'
    doc = Asciidoctor.load_file source_file, safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    before nested include

    no includes here

    just good old-fashioned paragraph text

    after nested include

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 6
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9, 11]
    (expect (doc.blocks.map {|it| it.file }).uniq).to eql [source_file]
  end

  it 'should resolve nested include relative to include file' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-nested-include-in-subdir.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    before relative include

    contents of relative include

    after relative include

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 5
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9]
  end

  it 'should resolve include with single line paragraph' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-single-line-paragraph.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    single line paragraph

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should leave escaped include escaped' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-escaped-include.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    \include::multiple-paragraphs.adoc[]

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should resolve include at start of document' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-at-start.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    single line paragraph

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
  end

  it 'should resolve include at end of document' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-at-end.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    single line paragraph
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
  end

  it 'should resolve include with multiline paragraph' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-multiline-paragraph.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    first line
    second line
    third line

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 7]
  end

  it 'should resolve include with multiple paragraphs' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-multiple-paragraphs.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    first paragraph

    second paragraph
    with two lines

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 8]
  end

  it 'should resolve adjacent includes' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-adjacent-includes.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before includes

    single line paragraph
    single line paragraph

    after includes
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
  end

  it 'should resolve include that follows include with nested include' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-following-include-with-nested-include.adoc'),
      safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before

    before nested include

    no includes here

    just good old-fashioned paragraph text

    after nested include

    then

    no includes here

    just good old-fashioned paragraph text

    after
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 9
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9, 11, 13, 15, 17]
  end

  it 'should assign same line number to preamble and its paragraph' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-preamble.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Document Title

    single line paragraph

    == Chapter A

    == Chapter B
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 5
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 3, 5, 7]
  end

  it 'should skip top-level include that cannot be resolved' do
    doc = nil
    with_memory_logger do |logger|
      doc = Asciidoctor.load_file (fixture_file 'parent-with-unresolved-include.adoc'), safe: :safe
      (expect logger).to be_empty
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    Unresolved directive in parent-with-unresolved-include.adoc - include::no-such-file.adoc[]

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect doc.blocks[1].source).to start_with 'Unresolved directive'
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should skip optional top-level include that cannot be resolved' do
    doc = nil
    with_memory_logger do |logger|
      doc = Asciidoctor.load_file (fixture_file 'parent-with-optional-unresolved-include.adoc'), safe: :safe
      (expect logger).to be_empty
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include


    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4]
  end

  it 'should skip empty include' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-empty-include.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include
    after include

    before include


    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4, 7]
  end

  it 'should skip include that custom include processor handles but does not push' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-single-line-paragraph.adoc'), safe: :safe,
      extensions: proc { include_processor { process { next } } }
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include


    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4]
  end

  it 'should include lines pushed by custom include processor' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-single-line-paragraph.adoc'), safe: :safe,
      extensions: proc {
        include_processor do
          process do |_, reader, target, attrs|
            reader.push_include ['pushed first', '', 'pushed last'], target, target, 1, attrs
          end
        end
      }
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    pushed first

    pushed last

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
  end

  it 'should not replace lines if the target line does not match the expected line' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-single-line-paragraph.adoc'), safe: :safe,
      extensions: proc {
        tree_processor do
          prefer
          process do |interim_doc|
            unless interim_doc.options[:reduced]
              inc_replacements = interim_doc.reader.instance_variable_get :@x_include_replacements
              inc_replacements[0][:replace] = 'include::not-a-match[]'
            end
          end
        end
      }
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    include::single-line-paragraph.adoc[]

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should not rebuild document if no includes are found' do
    captured_interim_doc = nil
    doc = Asciidoctor.load_file (fixture_file 'parent-with-no-includes.adoc'), safe: :safe,
      extensions: proc {
        tree_processor do
          prefer
          process do |interim_doc|
            interim_doc.options[:reduced] ? interim_doc : (captured_interim_doc = interim_doc)
          end
        end
      }
    expect(captured_interim_doc).to be doc
  end

  it 'should resolve include with tag' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-tag.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    Start of body.

    End of body.

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
  end

  it 'should resolve include with tags' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-tags.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    The beginning.
    The end.

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
  end

  it 'should resolve include with lines' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-lines.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    first paragraph, second line

    second paragraph, first line
    second paragraph, second line

    third paragraph

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 5
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 8, 10]
  end

  it 'should resolve include with leveloffset' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-leveloffset.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Document Title

    == Section

    :leveloffset: +1

    == Subsection

    === Nested Subsection

    :leveloffset!:

    == Another Section
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.find_by context: :section
    (expect blocks).to have_size 5
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 7, 9, 13]
  end

  it 'should resolve include between leveloffset attribute entries' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-leveloffset-and-include.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Document Title

    == Section

    :leveloffset: +1
    == Subsection

    === Nested Subsection

    :!leveloffset:
    == Another Section
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 5
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 6, 8, 11]
  end

  it 'should preserve attribute entries in the document header' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-header-attributes.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Document Title
    :sectnums:
    :icons: font
    :toc:

    before include

    single line paragraph

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [6, 8, 10]
    (expect (doc.attr? 'sectnums')).to be true
    (expect (doc.attr? 'icons', 'font')).to be true
    (expect (doc.attr? 'toc')).to be true
  end

  it 'should use attribute defined in header when resolving include' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-attribute-reference-from-header.adoc'),
      safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Book Title
    :chaptersdir: chapters

    == Chapter One

    content
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 3
    (expect (blocks.map {|it| it.lineno })).to eql [1, 4, 6]
  end

  it 'should use attribute defined in body when resolving include' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-attribute-reference-from-body.adoc'),
      safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Book Title
    :doctype: book

    Preamble.

    :includesdir: chapters
    == Chapter One

    content

    :includesdir: appendices
    [appendix]
    == Installation

    content
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 7
    (expect (blocks.map {|it| it.lineno })).to eql [1, 4, 4, 7, 9, 13, 15]
  end

  it 'should use attribute defined inside preprocessor conditional header when resolving include' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-attribute-reference-from-pp-conditional.adoc'),
      safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Book Title
    ifndef::chaptersdir[:chaptersdir: chapters]

    == Chapter One

    content
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 3
    (expect (blocks.map {|it| it.lineno })).to eql [1, 4, 6]
  end

  it 'should use attribute passed to API when resolving include' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-attribute-reference-in-target.adoc'),
      safe: :safe, attributes: 'chaptersdir=chapters'
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Book Title

    == Chapter One

    content
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 3
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should use attribute passed to API when resolving attribute value on include directive' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-attribute-reference-as-tag.adoc'),
      safe: :safe, attributes: 'tag=body'
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    Start of body.

    End of body.

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
  end

  it 'should not resolve include inside false preprocessor conditional' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-inside-false-pp-conditional.adoc'), safe: :safe
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    ifdef::no-such-attribute[]
    include::single-line-paragraph.adoc[]

    endif::[]
    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 7]
  end

  it 'should not log messages generated by document' do
    with_memory_logger do |logger|
      Asciidoctor.load_file (fixture_file 'document-with-warnings.adoc'), safe: :safe
      (expect logger.messages).to be_empty
      (expect Asciidoctor::LoggerManager.logger).to be logger
    end
  end

  it 'should restore original logger' do
    default_logger = Asciidoctor::LoggerManager.logger
    custom_logger = Asciidoctor::LoggerManager.logger = Asciidoctor::MemoryLogger.new
    custom_logger.warn 'before'
    Asciidoctor.load_file (fixture_file 'document-with-warnings.adoc'), safe: :safe
    (expect Asciidoctor::LoggerManager.logger).to be custom_logger
    (expect custom_logger.messages).to have_size 1
    (expect custom_logger.messages[0][:message]).to eql 'before'
  ensure
    Asciidoctor::LoggerManager.logger = default_logger
  end
end
