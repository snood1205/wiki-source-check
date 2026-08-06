# frozen_string_literal: true

require 'strscan'

module Wikipedia
  module Wikitext
    # The scan shared by the wikitext parsers.
    #
    # Any parser implementing this must define outside, opener, and ignore
    module Parser
      attr_reader :wikitext

      def initialize(wikitext, offset: 0)
        @wikitext = wikitext
        @offset = offset
      end

      def self.parsed_attr(*attrs)
        attrs.each do |attr|
          name = "@#{attr}"
          define_method attr do
            return instance_variable_get name if instance_variable_defined? name

            parse
            instance_variable_get name
          end
        end
      end

      parsed_attr :unclosed, :closed

      private

      def ignore = nil

      def parse
        @closed = []
        @unclosed = []
        scan StringScanner.new(wikitext)
      end

      def scan(scanner)
        until scanner.eos?
          scanner.skip outside
          break if scanner.eos?

          consume scanner
        end
      end

      def consume(scanner)
        return if ignore && scanner.skip(ignore)

        scanner_offset = scanner.pos + @offset
        return scanner.getch unless scanner.scan(opener)

        record scanner, scanner_offset
      end
    end
  end
end
