# frozen_string_literal: true

module MemexRAG
  module Parser
    class Base
      attr_reader :file_object

      def initialize(file_object)
        raise ArgumentError, "Expected an FileObject, got #{file_object.class}" unless file_object.is_a?(FileObject)

        @file_object = file_object
      end

      # Helper method for path access
      def file_path
        @file_object.path
      end

      # Instance method parse must be implemented by subclasses
      def parse
        raise NotImplementedError, "#{self.class} must implement the instance method #parse"
      end

      protected

      # Helper to read file content using UTF-8 encoding
      def read_file
        File.read(file_path, encoding: 'UTF-8')
      rescue StandardError => e
        logger.error "Error reading file #{file_path}: #{e.message}"
        raise # Re-raise the error or handle appropriately
      end

      # Provides common file-level metadata from the FileObject
      def basic_metadata
        {
          format: file_object.extension[1..]&.downcase, # Safe navigation & downcase
          parser: self.class.name,
          parsed_at: Time.now.utc.iso8601,
          file_path: file_object.path.to_s,
          file_name: file_object.name,
          file_size: file_object.size,
          mime_type: file_object.mime_type
        }
      end

      # Class method for checking handle remains (used by FileLoader before instantiation)
      # Assumes Logging module provides logger_for class method
      def self.handles?(file_path, extensions, content_types)
        p_path = Pathname(file_path)

        # Basic checks
        unless p_path.exist? && p_path.file?
          logger.warn "Path does not exist or is not a file: #{file_path}"
          return false
        end

        extension = p_path.extname.downcase
        return true if extensions.include?(extension)

        # MIME type check (optional, requires Marcel)
        begin
          require 'marcel' unless defined?(Marcel)
          mime_type = Marcel::MimeType.for(p_path)
          return content_types.include?(mime_type) if mime_type
        rescue LoadError
          logger.warn "Marcel gem not loaded. Cannot check MIME type for #{p_path}."
        rescue StandardError => e
          logger.warn "Could not determine MIME type for #{p_path}: #{e.message}"
        end

        # Fallback if extension didn't match and MIME check failed/skipped
        false
      end
    end
  end
end
