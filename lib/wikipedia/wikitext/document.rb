# frozen_string_literal: true

require 'forwardable'

require_relative 'citation'
require_relative 'ref_parser'
require_relative 'template_parser'

module Wikipedia
  module Wikitext
    # An article's refs and the citations inside them.
    class Document
      extend Forwardable

      attr_reader :wikitext

      def_delegators :ref_parser, :refs, :unclosed

      def initialize(wikitext)
        @wikitext = wikitext
      end

      def citations = @citations ||= refs.flat_map { |ref| citations_in ref }

      def uses = @uses ||= refs.select(&:self_closing?)

      def definitions = refs - uses

      def definitions_by_name = @definitions_by_name ||= index(definitions)

      def uses_by_name = @uses_by_name ||= index(uses)

      def orphans = uses_by_name.keys - definitions_by_name.keys

      def untemplated = definitions - citations.map(&:ref)

      private

      def ref_parser = @ref_parser ||= RefParser.new(wikitext)

      def index(refs) = refs.select(&:named?).group_by(&:name)

      def citations_in(ref)
        return [] unless ref.content

        TemplateParser.new(ref.content, offset: ref.content_offset).templates.map do |template|
          Citation.new template:, ref:
        end
      end
    end
  end
end
