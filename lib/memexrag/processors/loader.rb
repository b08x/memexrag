# lib/langchain/custom_file_loader.rb
require 'langchain'
require 'base64' # For context, though not strictly used for decoding in this version
require 'securerandom' # For generating UUIDs

module Langchain
  class CustomFileLoader
    attr_reader :markdown_separators, :html_separators, :generic_text_separators

    # Regex for base64 embedded images
    BASE64_IMAGE_REGEX = %r{!\[(?<alt_text>[^\]]*)\]\(data:image/(?<type>\w+);base64,(?<data>[^)]+)\)}

    # Regex for referenced images (e.g., ![alt text](/path/to/image.png))
    REFERENCED_IMAGE_REGEX = /!\[(?<alt_text>[^\]]*)\]\((?<path>[^)]+)\)/

    # Regex to match markdown tables
    # Captures a table with at least one header row, separator row, and one data row
    MARKDOWN_TABLE_REGEX = /(?<table>^\|.+\|\n\|[-:|]+\|\n\|.+\|(\n\|.+\|)*)$/m

    def initialize(markdown_separators: ["\n## ", "\n### ", "\n#### ", "\n##### ", "\n###### ", "\n* ", "\n- ", "\n  * ", "\n  - "],
                   html_separators: ["\n\n", "\n", ' ', ''],
                   generic_text_separators: ["\n\n", "\n", '. ', '? ', '! ', ' ', ''])
      @markdown_separators = markdown_separators
      @html_separators = html_separators
      @generic_text_separators = generic_text_separators
    end

    def load_and_process(file_path, chunk_size: 2000, chunk_overlap: 0)
      loader = Langchain::Loader.new(file_path)
      raw_data_object = loader.load
      original_text_content = raw_data_object.value # Get the raw text

      file_extension = File.extname(file_path).downcase
      extracted_images = []
      extracted_tables = []
      text_to_chunk = original_text_content.dup # Work with a copy for modification

      chunker_options = {
        chunk_size: chunk_size,
        chunk_overlap: chunk_overlap
      }

      case file_extension
      when '.md', '.markdown'
        logger.info "Processing Markdown file: #{file_path}"

        # Scan for images and extract them, while also modifying text_to_chunk
        # Using gsub with a block allows both extraction and modification in one pass ( conceptually)
        # However, for clarity and to collect all images first, we'll scan then gsub.

        image_uuids = {} # To store UUIDs for each image, keyed by the full image tag
        table_uuids = {} # To store UUIDs for each table, keyed by the full table content

        # Extract base64 embedded images
        original_text_content.scan(BASE64_IMAGE_REGEX) do |_full_image_tag_match|
          match_data = Regexp.last_match # Access named captures for alt_text, type, data
          image_uuid = SecureRandom.uuid
          image_uuids[match_data[0]] = image_uuid # Store UUID keyed by the full image string

          extracted_images << {
            id: image_uuid, # Add UUID to the image metadata
            alt_text: match_data[:alt_text],
            type: match_data[:type],
            base64_data: match_data[:data],
            image_type: 'base64'
          }
        end

        # Extract referenced images
        original_text_content.scan(REFERENCED_IMAGE_REGEX) do |_full_image_tag_match|
          match_data = Regexp.last_match

          # Skip if this is a base64 image (would match both regexes)
          next if match_data[:path].start_with?('data:image/')

          image_uuid = SecureRandom.uuid
          image_uuids[match_data[0]] = image_uuid # Store UUID keyed by the full image string

          extracted_images << {
            id: image_uuid,
            alt_text: match_data[:alt_text],
            path: match_data[:path],
            image_type: 'referenced'
          }
        end

        logger.info "Extracted #{extracted_images.count} images with UUIDs from #{file_path}."

        # Scan for tables and extract them
        original_text_content.scan(MARKDOWN_TABLE_REGEX) do |_full_table_match|
          match_data = Regexp.last_match
          table_content = match_data[:table]
          table_uuid = SecureRandom.uuid
          table_uuids[table_content] = table_uuid

          # Extract table rows for structured storage
          rows = table_content.split("\n").map { |row| row.strip.split('|').map(&:strip).reject(&:empty?) }

          extracted_tables << {
            id: table_uuid,
            content: table_content,
            rows: rows
          }
        end
        logger.info "Extracted #{extracted_tables.count} markdown tables with UUIDs from #{file_path}."

        # Replace base64 image tags with placeholders
        text_to_chunk.gsub!(BASE64_IMAGE_REGEX) do |matched_image_tag|
          current_match_data = Regexp.last_match
          uuid = image_uuids[matched_image_tag]
          "[IMAGE:#{uuid}:#{current_match_data[:alt_text]}]"
        end

        # Replace referenced image tags with placeholders
        text_to_chunk.gsub!(REFERENCED_IMAGE_REGEX) do |matched_image_tag|
          # Skip if this is a base64 image (would match both regexes)
          current_match_data = Regexp.last_match
          next matched_image_tag if current_match_data[:path].start_with?('data:image/')

          uuid = image_uuids[matched_image_tag]
          "[IMAGE:#{uuid}:#{current_match_data[:alt_text]}]"
        end

        # Replace tables with placeholders including the UUID
        text_to_chunk.gsub!(MARKDOWN_TABLE_REGEX) do |matched_table|
          uuid = table_uuids[matched_table]
          "[TABLE:#{uuid}]"
        end

        chunker_options[:separators] = @generic_text_separators
        logger.info "Using Markdown separators for #{file_path} (image tags removed)."

      when '.html', '.htm'
        # HTML processing by Langchain::Processors::HTML already strips tags.
        # text_to_chunk here is already the extracted text.
        chunker_options[:separators] = @html_separators
        logger.info "Using HTML-tuned separators for #{file_path}"
      when '.txt'
        chunker_options[:separators] = @generic_text_separators
        logger.info "Using generic text separators for #{file_path}"
      else
        begin
          loader.send(:processor_klass) # Internal check, conceptual
          chunker_options[:separators] = @generic_text_separators
          logger.info "Using generic text separators for unspecialized file type: #{file_path}"
        rescue Langchain::Loader::UnknownFormatError
          logger.error "Unknown file format for #{file_path}. Cannot determine chunking strategy."
          # If loader.load itself didn't raise, but we still can't classify, use generic.
          # However, loader.load would typically raise for truly unknown/unprocessable types.
          chunker_options[:separators] = @generic_text_separators
        end
      end

      # Perform chunking on the (potentially modified) text content
      text_splitter = Langchain::Chunker::RecursiveText.new(
        text_to_chunk, # This is key: use the (modified) text_to_chunk
        **chunker_options
      )
      text_chunks = text_splitter.chunks

      {
        chunks: text_chunks,
        extracted_images: extracted_images, # This list contains the actual image data
        extracted_tables: extracted_tables  # This list contains the extracted tables
      }
    end
  end
end
