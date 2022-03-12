# frozen_string_literal: true

require_relative 'spec_helper'
require 'asciidoctor/reducer/include_mapper/extension'

describe Asciidoctor::Reducer::IncludeMapper do
  it 'should not add include mapping comment if document has no includes' do
    ext_class = described_class
    scenario = create_scenario do
      input_source <<~'EOS'
      no includes here

      not a single one
      EOS

      reduce_options extensions: proc {
        next if document.options[:reduced]
        tree_processor ext_class
      }
    end
    (expect scenario.doc.source_lines[-1]).to eql 'not a single one'
  end

  it 'should not add include mapping comment if document only has partial includes' do
    ext_class = described_class
    scenario = create_scenario do
      input_source <<~'EOS'
      before include

      include::include-with-tag.adoc[tag=body]

      after include
      EOS

      reduce_options extensions: proc {
        next if document.options[:reduced]
        tree_processor ext_class
      }
    end
    (expect scenario.doc.source_lines[-1]).to eql 'after include'
  end

  it 'should add include mapping comment to bottom of reduced file' do
    ext_class = described_class
    include_file = nil
    scenario = create_scenario do
      include_file = create_include_file <<~'EOS'
      before nested include

      include::no-includes.adoc[]

      after nested include
      EOS

      input_source <<~EOS
      before include

      include::#{include_file}[]

      after include
      EOS

      reduce_options extensions: proc {
        next if document.options[:reduced]
        tree_processor ext_class
      }
    end
    (expect scenario.doc.source_lines[-1]).to eql %(//# includes=#{File.basename include_file, '.adoc'},no-includes)
  end

  it 'should only add entries to include mapping comment that are included fully' do
    ext_class = described_class
    scenario = create_scenario do
      input_source <<~'EOS'
      beginning

      include::single-line-paragraph.adoc[]

      include::include-with-tag.adoc[tag=body]

      end
      EOS

      reduce_options extensions: proc {
        next if document.options[:reduced]
        tree_processor ext_class
      }
    end
    (expect scenario.doc.source_lines[-1]).to eql '//# includes=single-line-paragraph'
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
    scenario = create_scenario do
      input_source <<~'EOS'
      before include

      include::no-includes.adoc[]

      after include
      EOS
    end
    (expect scenario.doc.source_lines[-1]).to eql '//# includes=no-includes'
  ensure
    Asciidoctor::Extensions.unregister Asciidoctor::Extensions.groups.keys.last
  end
end
