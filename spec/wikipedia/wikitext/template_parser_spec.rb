# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wikipedia::Wikitext::TemplateParser do
  subject(:parser) { described_class.new wikitext }

  describe '#templates' do
    context 'when the wikitext has no templates' do
      let(:wikitext) { 'Apples are a fruit.' }

      it 'returns an empty array' do
        expect(parser.templates).to be_empty
      end
    end

    context 'with a template that takes no params' do
      let(:wikitext) { '{{citation needed}}' }

      it 'extracts the template' do
        expect(parser.templates.size).to eq 1
      end

      it 'captures the name' do
        expect(parser.templates.first.name).to eq 'citation needed'
      end

      it 'has no params' do
        expect(parser.templates.first.params).to be_empty
      end
    end

    context 'with named params' do
      let(:wikitext) { '{{cite web|url=https://example.com|title=An example}}' }

      it 'captures the name' do
        expect(parser.templates.first.name).to eq 'cite web'
      end

      it 'captures every param' do
        expect(parser.templates.first.params).to eq('url' => 'https://example.com', 'title' => 'An example')
      end

      it 'reads a param by key' do
        expect(parser.templates.first['url']).to eq 'https://example.com'
      end
    end

    context 'with a value containing an equals sign' do
      let(:wikitext) { '{{cite web|url=https://example.com/?a=1&b=2}}' }

      it 'splits on the first equals sign only' do
        expect(parser.templates.first['url']).to eq 'https://example.com/?a=1&b=2'
      end
    end

    context 'with positional params' do
      let(:wikitext) { '{{lang|fr|pomme}}' }

      it 'numbers them from one' do
        expect(parser.templates.first.params).to eq('1' => 'fr', '2' => 'pomme')
      end

      it 'lists them in order' do
        expect(parser.templates.first.positional).to eq %w[fr pomme]
      end
    end

    context 'with positional and named params mixed' do
      let(:wikitext) { '{{lang|fr|pomme|italic=no}}' }

      it 'numbers only the positional ones' do
        expect(parser.templates.first.params).to eq('1' => 'fr', '2' => 'pomme', 'italic' => 'no')
      end
    end

    context 'with whitespace around params' do
      let(:wikitext) { '{{cite web | url = https://example.com | title = An example }}' }

      it 'strips the keys and values' do
        expect(parser.templates.first.params).to eq('url' => 'https://example.com', 'title' => 'An example')
      end
    end

    context 'with a multiline template' do
      let(:wikitext) do
        <<~WIKITEXT
          {{cite book
           |title=Programming Ruby
           |year=2004
          }}
        WIKITEXT
      end

      it 'captures the params across lines' do
        expect(parser.templates.first.params).to eq('title' => 'Programming Ruby', 'year' => '2004')
      end
    end

    context 'with an uppercase param key' do
      let(:wikitext) { '{{cite web|URL=https://example.com}}' }

      it 'preserves the key case, which MediaWiki treats as significant' do
        expect(parser.templates.first['URL']).to eq 'https://example.com'
      end

      it 'does not answer to the lowercase spelling' do
        expect(parser.templates.first['url']).to be_nil
      end
    end

    context 'with an empty param value' do
      let(:wikitext) { '{{cite web|url=https://example.com|title=}}' }

      it 'keeps the key with an empty value' do
        expect(parser.templates.first['title']).to eq ''
      end
    end

    context 'with multiple templates' do
      let(:wikitext) { 'One {{cite web|url=https://a.example}} two {{cite book|title=B}}' }

      it 'extracts every template' do
        expect(parser.templates.size).to eq 2
      end

      it 'preserves document order' do
        expect(parser.templates.map(&:name)).to eq ['cite web', 'cite book']
      end

      it 'records the offset of each template' do
        expect(parser.templates.map(&:offset)).to eq [4, 43]
      end
    end

    context 'with a nested template' do
      let(:wikitext) { '{{cite web|title={{lang|fr|Pomme}}|url=https://example.com}}' }

      it 'collects only the top level template' do
        expect(parser.templates.size).to eq 1
      end

      it 'does not split on the pipes inside the nested template' do
        expect(parser.templates.first['title']).to eq '{{lang|fr|Pomme}}'
      end

      it 'still reads the param that follows' do
        expect(parser.templates.first['url']).to eq 'https://example.com'
      end
    end

    context 'with a doubly nested template' do
      let(:wikitext) { '{{cite web|title={{small|{{lang|fr|Pomme}}}}|year=2004}}' }

      it 'keeps the whole nest in the param' do
        expect(parser.templates.first['title']).to eq '{{small|{{lang|fr|Pomme}}}}'
      end

      it 'still reads the param that follows' do
        expect(parser.templates.first['year']).to eq '2004'
      end
    end

    context 'with a piped wikilink in a param' do
      let(:wikitext) { '{{cite book|title=[[Apple|apples]]|year=2004}}' }

      it 'does not treat the link pipe as a param separator' do
        expect(parser.templates.first['title']).to eq '[[Apple|apples]]'
      end

      it 'still reads the param that follows' do
        expect(parser.templates.first['year']).to eq '2004'
      end
    end

    context 'with an external link in a param' do
      let(:wikitext) { '{{cite book|title=[https://example.com An example]|year=2004}}' }

      it 'keeps the link intact' do
        expect(parser.templates.first['title']).to eq '[https://example.com An example]'
      end
    end

    context 'with a template name that uses underscores' do
      let(:wikitext) { '{{Cite_web|url=https://example.com}}' }

      it 'preserves the raw name' do
        expect(parser.templates.first.name).to eq 'Cite_web'
      end

      it 'reads underscores as spaces' do
        expect(parser.templates.first.normalized_name).to eq 'Cite web'
      end
    end

    context 'with a lowercase first letter in the template name' do
      let(:wikitext) { '{{cite web|url=https://example.com}}' }

      it 'capitalizes the first letter, which MediaWiki does not distinguish' do
        expect(parser.templates.first.normalized_name).to eq 'Cite web'
      end
    end

    context 'with an uppercase letter later in the template name' do
      let(:wikitext) { '{{cite Web|url=https://example.com}}' }

      it 'leaves it alone, since it names a different template' do
        expect(parser.templates.first.normalized_name).to eq 'Cite Web'
      end
    end

    context 'with a duplicated param key' do
      let(:wikitext) { '{{cite web|title=First|title=Second}}' }

      it 'keeps the last value, as MediaWiki does' do
        expect(parser.templates.first['title']).to eq 'Second'
      end
    end

    context 'with a single brace in the text' do
      let(:wikitext) { 'A { brace and {{cite web|url=https://example.com}}' }

      it 'extracts the template' do
        expect(parser.templates.size).to eq 1
      end
    end
  end

  describe '#key?' do
    subject(:template) { parser.templates.first }

    let(:wikitext) { '{{cite web|url=https://example.com}}' }

    it 'is true for a param that is present' do
      expect(template.key?('url')).to be true
    end

    it 'is false for a param that is absent' do
      expect(template.key?('title')).to be false
    end

    it 'accepts a symbol' do
      expect(template.key?(:url)).to be true
    end
  end

  describe '#unclosed' do
    context 'when every template is closed' do
      let(:wikitext) { '{{cite web|url=https://example.com}}' }

      it 'is empty' do
        expect(parser.unclosed).to be_empty
      end
    end

    context 'with an unclosed template' do
      let(:wikitext) { 'Text {{cite web|url=https://example.com' }

      it 'reports the unclosed template' do
        expect(parser.unclosed.size).to eq 1
      end

      it 'records where it started' do
        expect(parser.unclosed.first.offset).to eq 5
      end

      it 'captures the params it did read' do
        expect(parser.unclosed.first['url']).to eq 'https://example.com'
      end

      it 'does not include it among the well formed templates' do
        expect(parser.templates).to be_empty
      end
    end

    context 'with a closed template before an unclosed one' do
      let(:wikitext) { '{{cite web|title=A}} {{cite book|title=B' }

      it 'still extracts the closed template' do
        expect(parser.templates.map { |template| template['title'] }).to eq %w[A]
      end

      it 'reports the unclosed template' do
        expect(parser.unclosed.map { |template| template['title'] }).to eq %w[B]
      end
    end
  end
end
