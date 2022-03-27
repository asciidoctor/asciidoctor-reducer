# frozen_string_literal: true

describe Asciidoctor::Reducer::Extensions do
  describe_method '.group' do
    it 'should return extension group' do
      group = subject.call
      (expect group).to be_kind_of Proc
      doc = Asciidoctor.load []
      reg = (Asciidoctor::Extensions.create described_class.key, &group).activate doc
      (expect reg.preprocessors).to have_size 1
      (expect reg.treeprocessors).to have_size 1
    end
  end

  describe_method '.key' do
    it 'should return key for extension group' do
      (expect subject.call).to eql :reducer
    end
  end

  describe_method '.prepare_registry' do
    it 'should prepare new registry if no registry is specified and extension group is not registered globally' do
      registry = subject.call
      (expect registry).not_to be_nil
      (expect registry.groups.keys).to have_size 1
      (expect registry.groups[described_class.key]).not_to be_nil
    end

    it 'should not prepare new registry if no registry is specified and extension group is registered globally' do
      described_class.register
      registry = subject.call
      (expect registry).to be_nil
    ensure
      described_class.unregister
    end

    it 'should add extension group to specified registry if not present' do
      seed_registry = ::Asciidoctor::Extensions.create :seed do
        tree_processor do
          process do |doc|
            doc.source_lines << '// looks good!'
            doc
          end
        end
      end
      registry = subject.call seed_registry
      (expect registry).not_to be_nil
      (expect registry.groups.keys).to have_size 2
      (expect registry.groups.keys).to eql [:seed, described_class.key]
      (expect registry.groups[described_class.key]).not_to be_nil
      run_scenario do
        input_source 'include::single-line-paragraph.adoc[]'
        reduce_options safe: :safe, extension_registry: registry
        reduce { Asciidoctor.load_file input_file, reduce_options }
        expected_source <<~'END'
        single line paragraph
        // looks good!
        END
      end
    end

    it 'should prepare a new registry from proc and add extension group' do
      seed_registry_proc = proc do
        tree_processor do
          process do |doc|
            doc.source_lines << '// looks good!'
            doc
          end
        end
      end
      registry = subject.call seed_registry_proc
      (expect registry).not_to be_nil
      (expect registry.groups.keys).to have_size 2
      (expect registry.groups[described_class.key]).not_to be_nil
      run_scenario do
        input_source 'include::single-line-paragraph.adoc[]'
        reduce_options safe: :safe, extension_registry: registry
        reduce { Asciidoctor.load_file input_file, reduce_options }
        expected_source <<~'END'
        single line paragraph
        // looks good!
        END
      end
    end
  end

  describe_method '.register' do
    after { Asciidoctor::Extensions.unregister described_class.key if Asciidoctor::Extensions.groups }

    it 'should register extensions globally under group name' do
      subject.call
      (expect Asciidoctor::Extensions.groups).to have_key described_class.key
      doc = Asciidoctor.load []
      reg = Asciidoctor::Extensions::Registry.new.activate doc
      (expect reg.preprocessors).to have_size 1
      (expect reg.treeprocessors).to have_size 1
    end
  end

  describe_method '.unregister' do
    after { Asciidoctor::Extensions.unregister described_class.key if Asciidoctor::Extensions.groups }

    it 'should not fail if extensions are not registered globally' do
      Asciidoctor::Extensions.groups
      Asciidoctor::Extensions.remove_instance_variable :@groups
      expect { subject.call }.not_to raise_exception
      (expect Asciidoctor::Extensions.groups).not_to have_key described_class.key
    end

    it 'should unregister extensions globally under group name' do
      Asciidoctor::Extensions.register described_class.key, &described_class.group
      (expect Asciidoctor::Extensions.groups).to have_key described_class.key
      subject.call
      (expect Asciidoctor::Extensions.groups).not_to have_key described_class.key
    end

    it 'should not failed if called consecutively' do
      Asciidoctor::Extensions.register described_class.key, &described_class.group
      (expect Asciidoctor::Extensions.groups).to have_key described_class.key
      subject.call
      (expect Asciidoctor::Extensions.groups).not_to have_key described_class.key
      subject.call
      (expect Asciidoctor::Extensions.groups).not_to have_key described_class.key
    end
  end
end
