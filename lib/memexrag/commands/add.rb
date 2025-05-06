# frozen_string_literal: true

module MemexRAG
  module Commands
    class Add < BaseCommand
      def self.description
        'Create a new collection'
      end

      def execute(*_args)
        collection = `gum input`.strip
        folder = `gum file --directory $HOME`
        puts collection
        puts folder
        # puts MemexRAG::Actions::ExampleAction.new(input: args.join(' ')).call
      end
    end
  end
end
