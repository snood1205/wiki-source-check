# frozen_string_literal: true

module Wikipedia
  module Wikitext
    # A single template extracted from wikitext.
    Template = Data.define(:name, :params, :offset) do
      def [](key) = params[key.to_s]

      def key?(key) = params.key? key.to_s

      def normalized_name = name.tr('_', ' ').gsub(/\s+/, ' ').strip.sub(/\A./, &:upcase)

      def positional = params.keys.grep(/\A\d+\z/).map { |key| params[key] }
    end
  end
end
