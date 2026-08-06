# frozen_string_literal: true

require_relative 'parser'
require_relative 'template'

module Wikipedia
  module Wikitext
    # Extracts templates from wikitext.
    class TemplateParser
      include Parser

      TEMPLATE_OFFSET = 2

      WIKI_LINK = /\[\[[^\[\]]*\]\]/
      EXTERNAL_LINK = /\[[^\[\]]*\]/
      LINK = Regexp.union WIKI_LINK, EXTERNAL_LINK

      def templates = closed

      private

      def outside = /[^{]+/

      def opener = '{{'

      def record(scanner, offset)
        template, closed = read scanner, offset
        (closed ? @closed : @unclosed) << template
      end

      def read(scanner, offset)
        segments = [+'']
        closed = false

        until scanner.eos?
          break closed = true if scanner.scan '}}'

          step scanner, segments
        end

        [build(segments, offset), closed]
      end

      def step(scanner, segments)
        if (text = scanner.scan(/[^{}|\[]+/) || scanner.scan(LINK))
          segments.last << text
        elsif scanner.scan '{{'
          nest scanner, segments
        elsif scanner.scan '|'
          segments << +''
        else
          segments.last << scanner.getch
        end
      end

      def nest(scanner, segments)
        start = scanner.pos - TEMPLATE_OFFSET
        read scanner, start
        segments.last << wikitext.byteslice(start, scanner.pos - start)
      end

      def build(segments, offset)
        name, *params = segments
        Template.new name: name.strip, params: build_params(params), offset:
      end

      def build_params(segments)
        position = 0

        segments.each_with_object({}) do |segment, params|
          key, separator, value = segment.partition '='

          if separator.empty?
            params[(position += 1).to_s] = segment.strip
          else
            params[key.strip] = value.strip
          end
        end
      end
    end
  end
end
