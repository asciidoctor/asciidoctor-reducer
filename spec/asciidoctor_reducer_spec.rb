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

  it 'should require extensions under group named reducer' do
    (expect Asciidoctor::Extensions.groups).to have_key :reducer
    doc = Asciidoctor.load []
    reg = Asciidoctor::Extensions::Registry.new.activate doc
    (expect reg.preprocessors).to have_size 1
    (expect reg.treeprocessors).to have_size 1
  end

  it 'should load document with no includes' do
    source_file = fixture_file 'parent-with-no-includes.adoc'
    doc = Asciidoctor.load_file source_file, safe: :safe, sourcemap: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    no includes to be found here

    not a one
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect doc.options[:reduced]).to be_falsy
    (expect doc.sourcemap).to be true
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
    (expect doc.attr 'docname').to eql 'parent-with-no-includes'
    (expect doc.attr 'docfile').to eql source_file
    (expect doc.attr 'docdir').to eql (File.dirname source_file)
  end

  it 'should not enable sourcemap on document with no includes' do
    source_file = fixture_file 'parent-with-no-includes.adoc'
    doc = Asciidoctor.load_file source_file, safe: :safe
    (expect doc.options[:reduced]).to be_falsy
    (expect doc.sourcemap).to be_falsy
    (expect doc.blocks[0].source_location).to be_nil
  end

  it 'should resolve top-level include with no nested includes' do
    source_file = fixture_file 'parent-with-single-include.adoc'
    doc = Asciidoctor.load_file source_file, safe: :safe, sourcemap: true
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
    (expect doc.catalog[:includes]['no-includes']).to be true
  end

  it 'should not enable sourcemap on reduced document' do
    source_file = fixture_file 'parent-with-single-include.adoc'
    doc = Asciidoctor.load_file source_file, safe: :safe
    (expect doc.options[:reduced]).to be_falsy
    (expect doc.sourcemap).to be_falsy
    (expect doc.blocks[0].source_location).to be_nil
  end

  it 'should not reload document with includes if sourcemap is not enabled' do
    docs = []
    result = Asciidoctor.load_file (fixture_file 'parent-with-single-include.adoc'), safe: :safe,
      extensions: proc {
        tree_processor do
          prefer
          process do |doc|
            docs << doc
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
    (expect docs).to have_size 1
    (expect docs[0].object_id).to eql result.object_id
    (expect result.source_lines).to eql expected_lines
    (expect result.catalog[:includes]['no-includes']).to be true
  end

  it 'should not register extensions in a custom extension registry twice when reloading document' do
    calls = []
    ext_reg = Asciidoctor::Extensions.create do
      preprocessor do
        prefer
        process do |doc|
          calls << (doc.options[:reduced] == true)
          nil
        end
      end
    end
    result = Asciidoctor.load_file (fixture_file 'parent-with-single-include.adoc'), safe: :safe, sourcemap: true,
      extension_registry: ext_reg
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    no includes here

    just good old-fashioned paragraph text

    after include
    EOS
    (expect result.source_lines).to eql expected_lines
    (expect calls).to have_size 2
    (expect calls).to eql [false, true]
  end

  it 'should resolve top-level include with nested include' do
    source_file = fixture_file 'parent-with-single-include-with-include.adoc'
    doc = Asciidoctor.load_file source_file, safe: :safe, sourcemap: true
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
    doc = Asciidoctor.load_file (fixture_file 'parent-with-nested-include-in-subdir.adoc'), safe: :safe, sourcemap: true
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
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-single-line-paragraph.adoc'), safe: :safe,
      sourcemap: true
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
    doc = Asciidoctor.load_file (fixture_file 'parent-with-escaped-include.adoc'), safe: :safe, sourcemap: true
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
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-at-start.adoc'), safe: :safe, sourcemap: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    single line paragraph

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
  end

  it 'should resolve include at end of document' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-at-end.adoc'), safe: :safe, sourcemap: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    single line paragraph
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
  end

  it 'should resolve include with multiline paragraph' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-multiline-paragraph.adoc'), safe: :safe,
      sourcemap: true
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
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-multiple-paragraphs.adoc'), safe: :safe,
      sourcemap: true
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
    doc = Asciidoctor.load_file (fixture_file 'parent-with-adjacent-includes.adoc'), safe: :safe, sourcemap: true
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
      safe: :safe, sourcemap: true
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
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-preamble.adoc'), safe: :safe, sourcemap: true
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

  it 'should flag top-level include that cannot be resolved as an unresolved directive' do
    doc = nil
    with_memory_logger do |logger|
      doc = Asciidoctor.load_file (fixture_file 'parent-with-unresolved-include.adoc'), safe: :safe, sourcemap: true
      messages = logger.messages
      (expect messages).to have_size 1
      (expect messages[0][:message][:text]).to include 'include file not found'
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

  it 'should resolve include after unresolved include' do
    doc = nil
    with_memory_logger do |logger|
      doc = Asciidoctor.load_file (fixture_file 'parent-with-include-after-unresolved-include.adoc'), safe: :safe,
        sourcemap: true
      messages = logger.messages
      (expect messages).to have_size 1
      (expect messages[0][:message][:text]).to include 'include file not found'
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    :optional:

    before includes

    Unresolved directive in parent-with-include-after-unresolved-include.adoc - include::no-such-file.adoc[{optional}]

    between includes

    single line paragraph

    after includes
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 5
    (expect doc.blocks[1].source).to start_with 'Unresolved directive'
    (expect (doc.blocks.map {|it| it.lineno })).to eql [3, 5, 7, 9, 11]
  end

  it 'should resolve include after unresolved optional include' do
    doc = nil
    with_memory_logger do |logger|
      doc = Asciidoctor.load_file (fixture_file 'parent-with-include-after-unresolved-include.adoc'), safe: :safe,
        attributes: { 'optional' => 'opts=optional' }, sourcemap: true
      messages = logger.messages
      (expect messages).to have_size 1
      (expect messages[0][:message][:text]).to include 'include file not found'
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    :optional:

    before includes


    between includes

    single line paragraph

    after includes
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [3, 6, 8, 10]
  end

  it 'should skip optional top-level include that cannot be resolved' do
    doc = nil
    with_memory_logger do |logger|
      doc = Asciidoctor.load_file (fixture_file 'parent-with-optional-unresolved-include.adoc'), safe: :safe,
        sourcemap: true
      messages = logger.messages
      (expect messages).to have_size 1
      (expect messages[0][:message][:text]).to include 'include file not found'
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include


    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4]
  end

  it 'should flag nested include that cannot be resolved as an unresolved directive' do
    doc = nil
    with_memory_logger do |logger|
      doc = Asciidoctor.load_file (fixture_file 'parent-with-nested-unresolved-include.adoc'), safe: :safe,
        sourcemap: true
      messages = logger.messages
      (expect messages).to have_size 1
      (expect messages[0][:message][:text]).to include 'include file not found'
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    before top-level include

    before include

    Unresolved directive in parent-with-unresolved-include.adoc - include::no-such-file.adoc[]

    after include

    after top-level include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 5
    (expect doc.blocks[2].source).to start_with 'Unresolved directive'
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9]
  end

  it 'should flag include as an unresolved directive if target is empty' do
    doc = nil
    with_memory_logger do |logger|
      doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-empty-target.adoc'), safe: :safe,
        sourcemap: true
      messages = logger.messages
      (expect messages).to have_size 1
      (expect messages[0][:message][:text]).to include 'resolved target is blank'
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    Unresolved directive in parent-with-include-with-empty-target.adoc - include::{empty}[]

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should skip empty include' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-empty-include.adoc'), safe: :safe, sourcemap: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include
    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 1
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1]
  end

  it 'should resolve include after empty include' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-after-empty-include.adoc'), safe: :safe,
      sourcemap: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    before includes


    between includes

    single line paragraph

    after includes
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4, 6, 8]
  end

  it 'should skip nested empty include' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-nested-empty-include.adoc'), safe: :safe, sourcemap: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    before top-level include

    before include
    after include

    after top-level include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
  end

  it 'should remove trailing empty lines when sourcemap is enabled' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-empty-trailing-include.adoc'), safe: :safe, sourcemap: true
    (expect doc.source_lines).to eql ['before include']
    (expect doc.blocks).to have_size 1
    (expect doc.blocks[0].lineno).to eql 1
  end

  it 'should remove trailing empty lines when sourcemap is not enabled' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-empty-trailing-include.adoc'), safe: :safe
    (expect doc.source_lines).to eql ['before include']
    (expect doc.blocks).to have_size 1
  end

  it 'should not crash if reduced document is empty' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-only-empty-include.adoc'), safe: :safe
    (expect doc.source_lines).to be_empty
    (expect doc.blocks).to be_empty
  end

  it 'should skip include that custom include processor handles but does not push' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-single-line-paragraph.adoc'), safe: :safe,
      sourcemap: true, extensions: proc { include_processor { process { next } } }
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
      sourcemap: true, extensions: proc {
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
      sourcemap: true, extensions: proc {
        tree_processor do
          prefer
          process do |interim_doc|
            unless interim_doc.options[:reduced]
              interim_doc.reader.x_include_replacements[1][:line] = 'include::not-a-match[]'
            end
            nil
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
            captured_interim_doc = interim_doc unless interim_doc.options[:reduced]
            nil
          end
        end
      }
    expect(captured_interim_doc).to be doc
  end

  it 'should resolve include with tag' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-tag.adoc'), safe: :safe, sourcemap: true
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
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-tags.adoc'), safe: :safe, sourcemap: true
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
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-lines.adoc'), safe: :safe, sourcemap: true
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
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-leveloffset.adoc'), safe: :safe, sourcemap: true
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
    doc = Asciidoctor.load_file (fixture_file 'parent-with-leveloffset-and-include.adoc'), safe: :safe, sourcemap: true
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
    doc = Asciidoctor.load_file (fixture_file 'parent-with-header-attributes.adoc'), safe: :safe, sourcemap: true
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
      safe: :safe, sourcemap: true
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
      safe: :safe, sourcemap: true
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
      safe: :safe, sourcemap: true
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

  it 'should use attribute passed to API when resolving include' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-attribute-reference-in-target.adoc'),
      safe: :safe, sourcemap: true, attributes: 'chaptersdir=chapters'
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
      safe: :safe, sourcemap: true, attributes: 'tag=body'
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

  it 'should skip include when attribute in target cannot be resolved and attribute-missing=drop-line' do
    doc = nil
    with_memory_logger do |logger|
      doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-attribute-reference-in-target.adoc'),
        attributes: { 'attribute-missing' => 'drop-line' }, safe: :safe, sourcemap: true
      messages = logger.messages
      (expect messages).to have_size 2
      (expect messages[1][:severity]).to eql :INFO
      (expect messages[1][:message][:text]).to include 'include dropped'
    end
    (expect doc.source_lines).to eql ['= Book Title']
    (expect doc.lineno).to eql 1
  end

  it 'should drop lines containing preprocessor directive when condition resolves to true' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-pp-conditional.adoc'), safe: :safe,
      attributes: { 'flag' => '' }, sourcemap: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    primary content
    conditional content

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
  end

  it 'should drop lines from start to end preprocessor directive when condition resolves to false' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-pp-conditional.adoc'), safe: :safe,
      sourcemap: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    primary content

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should drop single line preprocessor conditional that resolves to false' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-attribute-reference-from-pp-conditional.adoc'),
      safe: :safe, attributes: { 'chaptersdir' => 'chapters' }, sourcemap: true
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

  it 'should reduce preprocessor conditional following a nested include' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-pp-conditionals-and-include.adoc'),
      safe: :safe, attributes: { 'flag' => '' }, sourcemap: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    before nested include

    no includes here

    just good old-fashioned paragraph text

    after nested include

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.blocks
    (expect blocks).to have_size 6
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9, 11]
  end

  it 'should resolve include inside true preprocessor conditional' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-inside-true-pp-conditional.adoc'), safe: :safe,
      sourcemap: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    :flag:

    before include

    single line paragraph

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [3, 5, 7]
  end

  it 'should not resolve include inside false preprocessor conditional' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-inside-false-pp-conditional.adoc'), safe: :safe,
      sourcemap: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
  end

  it 'should keep preprocessor conditional if :preserve_conditionals option is set' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-inside-false-pp-conditional.adoc'), safe: :safe,
      preserve_conditionals: true, sourcemap: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    ifdef::no-such-attribute[]
    include::single-line-paragraph.adoc[]

    ifdef::backend[ignored]
    endif::[]
    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 8]
  end

  it 'should keep single line preprocessor conditional if :preserve_conditionals option is set and no includes' do
    doc = Asciidoctor.load_file (fixture_file 'parent-with-single-line-preprocessor-conditional.adoc'), safe: :safe,
      preserve_conditionals: true, sourcemap: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    ifdef::asciidoctor-version[text]
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 1
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1]
  end

  it 'should not log messages generated by document if null logger is specified' do
    with_memory_logger do |logger|
      silent_logger = Asciidoctor::NullLogger.new
      Asciidoctor.load_file (fixture_file 'document-with-warnings.adoc'), safe: :safe, logger: silent_logger
      (expect logger.messages).to be_empty
      (expect Asciidoctor::LoggerManager.logger).to be silent_logger
    end
  end

  it 'should suppress log messages when reloading document' do
    with_memory_logger do |logger|
      Asciidoctor.load_file (fixture_file 'parent-with-include-and-warning.adoc'), safe: :safe, sourcemap: true
      messages = logger.messages
      (expect messages).to have_size 1
      (expect messages[0][:severity]).to eql :WARN
      (expect messages[0][:message][:text]).to include 'unterminated'
      (expect Asciidoctor::LoggerManager.logger).to be logger
    end
  end
end
