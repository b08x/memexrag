# frozen_string_literal: true

require_relative 'base' # <--- Added: Needed because it inherits from Base
require 'lingua' # <--- Added: Fixes the 'uninitialized constant Lingua' error

module MemexRAG
  module Parser
    class PlainText < Base
      EXTENSIONS = ['.txt'].freeze
      CONTENT_TYPES = ['text/plain'].freeze

      # Initialize calls super(file_object) defined in Base
      def initialize(file_object)
        super # Pass the argument explicitly to super
        # logger is available via include Logging in Base
        logger.debug "Initialized PlainText parser for: #{file_path}" # Corrected log message
      end

      # Uses Base#read_file and Lingua
      def parse
        begin
          # read_file helper is inherited from Base
          file_content = read_file
        rescue StandardError => e
          logger.error "Error reading file in PlainText parser for #{file_path}: #{e.message}"
          return [] # Return empty array on read error
        end

        # Use Lingua
        content = Lingua::EN::Readability.new(file_content)
        metadata = {
          'word_count' => content.num_words,
          'char_count' => content.num_characters
          # NOTE: Base#basic_metadata provides file attributes; this only adds text stats
        }

        # Combine with basic file metadata from Base, if desired
        # combined_metadata = basic_metadata.merge(metadata)

        # Wrap the hash in an array as expected by FileLoader
        # Only returning Lingua-derived metadata here; FileLoader adds base file metadata
        [{ content: content.words.join(' '), metadata: metadata }]
      rescue Lingua::ConfigurationError => e
        logger.error "Lingua configuration error for #{file_path}: #{e.message}"
        []
      rescue StandardError => e
        logger.error "Error parsing plaintext #{file_path}: #{e.class} - #{e.message}"
        logger.error e.backtrace.first(5).join("\n")
        [] # Return empty array on parsing error
      end

      # Class method handles? uses Base implementation (correct because it inherits)
      def self.handles?(file_path)
        super(file_path, EXTENSIONS, CONTENT_TYPES)
      end
    end
  end
end
