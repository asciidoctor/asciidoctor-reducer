# frozen_string_literal: true

require_relative 'spec_helper'
require 'asciidoctor/reducer/include_mapper/extension'

describe Asciidoctor::Reducer::IncludeMapper do
  it 'should not add include mapping comment if document has no includes' do
    ext_class = described_class
    source_file = fixture_file 'parent-with-no-includes.adoc'
    doc = reduce_file source_file, extensions: proc {
      next if document.options[:reduced]
      tree_processor ext_class
    }
    (expect doc.source_lines[-1]).to eql 'not a one'
  end

  it 'should not add include mapping comment if document only has partial includes' do
    ext_class = described_class
    source_file = fixture_file 'parent-with-include-with-tag.adoc'
    doc = reduce_file source_file, extensions: proc {
      next if document.options[:reduced]
      tree_processor ext_class
    }
    (expect doc.source_lines[-1]).to eql 'after include'
  end

  it 'should add include mapping comment to bottom of reduced file' do
    ext_class = described_class
    source_file = fixture_file 'parent-with-single-include-with-include.adoc'
    doc = reduce_file source_file, extensions: proc {
      next if document.options[:reduced]
      tree_processor ext_class
    }
    (expect doc.source_lines[-1]).to eql '//# includes=include-with-include,no-includes'
  end

  it 'should only add entries to include mapping comment that are included fully' do
    ext_class = described_class
    source_file = fixture_file 'parent-with-includes-with-and-without-tag.adoc'
    doc = reduce_file source_file, extensions: proc {
      next if document.options[:reduced]
      tree_processor ext_class
    }
    (expect doc.source_lines[-1]).to eql '//# includes=single-line-paragraph'
  end

  it 'should load includes from mapping comment' do
    ext_class = described_class
    result = StringIO.new
    doc = Asciidoctor.convert <<~'EOS', to_file: result, extensions: proc { tree_processor ext_class }
    see xref:no-includes.adoc#sectid[]

    [#sectid]
    == Target Section

    //# includes=include-with-include,no-includes
    EOS
    includes = doc.catalog[:includes]
    (expect includes).to have_size 2
    (expect includes['include-with-include']).to be true
    (expect includes['no-includes']).to be true
    (expect result.string).to include '<a href="#sectid">Target Section</a>'
  end

  it 'should not load includes if mapping comment is missing' do
    ext_class = described_class
    result = StringIO.new
    doc = Asciidoctor.convert <<~'EOS', to_file: result, extensions: proc { tree_processor ext_class }
    see xref:no-includes.adoc#sectid[]

    [#sectid]
    == Target Section
    EOS
    (expect doc.catalog[:includes]).to be_empty
    (expect result.string).to include '<a href="no-includes.html#sectid">no-includes.html</a>'
  end

  it 'should not load includes if document is empty' do
    ext_class = described_class
    doc = Asciidoctor.load '', extensions: proc { tree_processor ext_class }
    (expect doc.catalog[:includes]).to be_empty
  end

  it 'should register include mapper extension globally when asciidoctor/reducer/include_mapper is required' do
    groups_size = Asciidoctor::Extensions.groups.size
    (expect require 'asciidoctor/reducer/include_mapper').not_to be_nil
    (expect Asciidoctor::Extensions.groups.size).to be > groups_size
    source_file = fixture_file 'parent-with-single-include-with-include.adoc'
    doc = reduce_file source_file
    (expect doc.source_lines[-1]).to eql '//# includes=include-with-include,no-includes'
  ensure
    Asciidoctor::Extensions.unregister Asciidoctor::Extensions.groups.keys.last
  end
end
