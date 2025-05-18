# frozen_string_literal: true

# Or, if this is for your own project structure, adjust accordingly, e.g., my_project/utils/image_converter.rb
require 'base64'
require 'tempfile'

module MemexRAG
  module Utils
    # Provides utility functions for handling image data, specifically
    # converting base64 encoded strings to temporary image files.
    module ImageConverter
      class Error < StandardError; end
      class Base64DecodingError < Error; end
      class FileWriteError < Error; end

      # Converts base64 encoded image data into a temporary image file object.
      # The caller is responsible for managing the Tempfile's lifecycle (closing and unlinking)
      # if not using the `with_temp_image_file` block method.
      #
      # @param base64_data [String] The base64 encoded image string.
      # @param image_type [String] The file extension for the image (e.g., "png", "jpeg").
      # @param alt_text [String] Optional descriptive name, used for logging and filename prefix.
      # @return [Tempfile] A Tempfile object representing the saved image. The file is closed after writing.
      # @raise [ArgumentError] If base64_data or image_type is invalid.
      # @raise [Base64DecodingError] If the base64_data cannot be decoded.
      # @raise [FileWriteError] If there's an issue writing the decoded data to the file.
      def self.base64_to_temp_file(base64_data:, image_type:, alt_text: 'image')
        unless base64_data && !base64_data.empty?
          logger.error "Base64 data is nil or empty for image '#{alt_text}'."
          raise ArgumentError, 'base64_data cannot be nil or empty.'
        end
        unless image_type && !image_type.empty?
          logger.error "Image type (extension) is nil or empty for image '#{alt_text}'."
          raise ArgumentError, 'image_type cannot be nil or empty.'
        end

        decoded_image_binary = begin
          Base64.strict_decode64(base64_data)
        rescue ArgumentError => e
          logger.error "Invalid Base64 string for image '#{alt_text}': #{e.message}"
          raise Base64DecodingError, "Failed to decode base64 string for '#{alt_text}' (data might be corrupted or not base64)."
        end

        # Sanitize alt_text for use in filename to avoid issues with special characters
        sanitized_prefix = alt_text.gsub(/[^0-9A-Za-z.\-_]/, '_').slice(0, 50) # Limit prefix length

        temp_file = Tempfile.new([sanitized_prefix, ".#{image_type.downcase}"])
        temp_file.binmode # Crucial for writing binary data like images

        begin
          temp_file.write(decoded_image_binary)
          logger.info "Decoded image '#{alt_text}' (size: #{decoded_image_binary.bytesize} bytes) written to temporary file: #{temp_file.path}"
        rescue IOError, SystemCallError => e
          logger.error "Failed to write decoded image '#{alt_text}' to temp file #{temp_file.path}: #{e.message}"
          temp_file.close! # Close and unlink immediately on write error
          raise FileWriteError, "Failed to write image data to temporary file for '#{alt_text}'."
        ensure
          # Close the file to ensure all data is flushed to disk and the file is ready for reading by other processes.
          # The caller of this method is responsible for unlinking if not using the block form.
          temp_file.close unless temp_file.closed?
        end

        temp_file
      end

      # A convenience method that takes base64 data, saves it to a temporary file,
      # yields the path of this file to a block, and ensures the temporary file is
      # cleaned up (closed and unlinked) after the block executes.
      #
      # @param base64_data [String] The base64 encoded image string.
      # @param image_type [String] The file extension for the image (e.g., "png", "jpeg").
      # @param alt_text [String] Optional descriptive name for logging and filename prefix.
      # @yield [String] The path to the temporary image file. The file is guaranteed to exist
      #                 and be closed (ready for reading) when yielded.
      # @return The result of the yielded block.
      #
      # @example
      #   description = MemexRAG::Utils::ImageConverter.with_temp_image_file(
      #     base64_data: "iVBORw0KGgo...",
      #     image_type: "png",
      #     alt_text: "ruby_logo"
      #   ) do |image_path|
      #     # chat = RubyLLM.chat(model: 'gpt-4o')
      #     # response = chat.ask("Describe this logo.", with: { image: image_path })
      #     # response.content # This would be the return value of the block
      #     "Simulated LLM description for image at #{image_path}"
      #   end
      #   puts description
      def self.with_temp_image_file(base64_data:, image_type:, alt_text: 'image', &block)
        temp_file_object = nil
        begin
          temp_file_object = base64_to_temp_file(
            base64_data: base64_data,
            image_type: image_type,
            alt_text: alt_text
          )
          # The file is already closed by base64_to_temp_file after writing.
          # We yield its path.
          block.call(temp_file_object.path)
        ensure
          if temp_file_object
            # Tempfile#close! also unlinks the file.
            # If already closed, #unlink is still needed if #close! wasn't the one closing it.
            temp_file_object.close unless temp_file_object.closed? # Ensure it's closed
            temp_file_object.unlink # Explicitly delete it
            logger.info "Cleaned up temporary image file: #{temp_file_object.path}"
          end
        end
      end
    end
  end
end
