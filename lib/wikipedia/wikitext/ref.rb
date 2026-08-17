# frozen_string_literal: true

module Wikipedia
  module Wikitext
    # A single <ref> tag extracted from wikitext.
    Ref = Data.define(:name, :group, :content, :content_offset, :self_closing, :offset) do
      def self_closing? = self_closing

      def named? = !name.nil?

      def group? = !group.nil?
    end
  end
end
