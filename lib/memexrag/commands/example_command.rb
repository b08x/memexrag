# frozen_string_literal: true

module MemexRAG
  module Commands
    class ExampleCommand < BaseCommand
      def self.description
        'An example command that generates a story based on the command line arguments.'
      end

      def execute(*args)
        p args
        logger.info 'test'
      end
    end
  end
end
