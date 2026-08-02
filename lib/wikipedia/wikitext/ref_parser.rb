# frozen_string_literal: true

require_relative 'parser'
require_relative 'ref'

module Wikipedia
  module Wikitext
    # Extracts <ref> tags from wikitext.
    class RefParser
      include Parser

      COMMENT = /<!--.*?-->/m
      NOWIKI = %r{<nowiki(?:\s[^>]*)?>.*?</nowiki\s*>|<nowiki\s*/>}mi
      PRE = %r{<pre(?:\s[^>]*)?>.*?</pre\s*>|<pre\s*/>}mi
      IGNORE = Regexp.union COMMENT, NOWIKI, PRE

      OPEN_REF = %r{<ref\b(?<attributes>[^>]*?)(?<self_closing>/)?\s*>}i

      ATTRIBUTE = /(?<key>\w+)\s*=\s*(?:"(?<quoted>[^"]*)"|'(?<single>[^']*)'|(?<bare>[^\s"'>]+))/

      def refs = closed

      private

      def outside = /[^<]+/

      def opener = OPEN_REF

      def ignore = IGNORE

      def record(scanner, offset)
        attributes = parse_attributes scanner[:attributes]

        if scanner[:self_closing]
          @closed << build_ref(attributes, nil, self_closing: true, offset:)
        elsif (body = scanner.scan_until(%r{</ref\s*>}i))
          @closed << build_ref(attributes, body[0...-scanner.matched.length], self_closing: false, offset:)
        else
          @unclosed << build_ref(attributes, scanner.rest, self_closing: false, offset:)
          scanner.terminate
        end
      end

      def build_ref(attributes, content, self_closing:, offset:)
        Ref.new name: attributes['name'], group: attributes['group'], content:, self_closing:, offset:
      end

      def parse_attributes(attributes)
        attributes.to_s.scan(ATTRIBUTE).each_with_object({}) do |(key, quoted, single, bare), parsed|
          parsed[key.downcase] = quoted || single || bare
        end
      end
    end
  end
end
