# frozen_string_literal: true

module MemexRAG
  module Parser
    class SRT < Base # Inherit from Base
      EXTENSIONS = ['.srt'].freeze
      CONTENT_TYPES = ['application/x-subrip', 'text/plain'].freeze # Added text/plain as fallback

      # Use handles? from Base class
      def self.handles?(file_path)
        super(file_path, EXTENSIONS, CONTENT_TYPES)
      end

      attr_reader :subtitles # Keep if needed internally

      # Updated initialize
      def initialize(file_object) # Parameter name consistency
        super # Call Base#initialize
        # @source = file_object # Removed redundant assignment
        # @path = file_object.path # Use file_path helper from Base
        @subtitles = []
        # @text = '' # Removed text accumulation if returning chunks
        logger.debug "Initialized SRT parser for: #{file_path}"
      end

      # Updated parse method
      def parse
        # File existence check happens in Base#read_file or FileObject init now
        logger.debug "Parsing SRT file: #{file_path}"
        begin
          # Use the ::SRT::File parser
          srt_file = ::SRT::File.parse(file_path.to_s) # Pass path string

          @subtitles = [] # Reset subtitles array
          srt_file.lines.each do |line|
            raw_text = line.text.join("\n").strip # Join multi-line text blocks
            next if raw_text.empty?

            @subtitles << {
              index: line.sequence,
              start_time: line.start_time, # Store as seconds (float)
              end_time: line.end_time,     # Store as seconds (float)
              text: raw_text,
              speaker: extract_speaker(raw_text) # Extract speaker if possible
            }
          end

          # Format output as array of hashes {chunk:, metadata:}
          result_array = @subtitles.map do |sub|
            {
              chunk: sub[:text],
              metadata: { # Only subtitle-specific metadata
                type: 'subtitle', # Add type for clarity
                index: sub[:index],
                start_time: sub[:start_time],
                end_time: sub[:end_time],
                duration: (sub[:end_time] - sub[:start_time]).round(3), # Calculate duration
                speaker: sub[:speaker] # Include speaker if found
                # Base file metadata (name, size, etc.) will be added by FileLoader
              }.compact # Remove nil values like speaker if not found
            }
          end
          logger.info "Parsed #{result_array.length} subtitles from #{file_path}"
          result_array
        rescue ::SRT::MalformedDataError => e
          logger.error "Malformed SRT data in file #{file_path}: #{e.message}"
          [] # Return empty array on parsing error
        rescue Errno::ENOENT => e
          logger.error "SRT file not found during parsing: #{file_path} - #{e.message}"
          []
        rescue StandardError => e
          logger.error "Error parsing SRT file #{file_path}: #{e.class} - #{e.message}"
          logger.error e.backtrace.first(5).join("\n")
          [] # Return empty array on general error
        end
      end

      # --- convert_to_vtt method can remain if needed, but ensure it uses file_path helper ---
      def convert_to_vtt
        output_path = file_path.sub_ext('.vtt')
        raise Errno::ENOENT, "Source SRT file not found: #{file_path}" unless file_path.exist?

        # Ensure WebVTT gem is available if this method is used
        require 'webvtt' unless defined?(WebVTT)
        vtt_result = WebVTT.convert_from_srt(file_path.cleanpath.to_s, output_path.to_s)
        logger.info "SRT converted to VTT - file placed in #{output_path}"
        vtt_result
      rescue LoadError
        logger.error 'WebVTT gem required for SRT to VTT conversion but not found.'
        nil
      rescue StandardError => e
        logger.error "Error converting SRT to VTT for #{file_path}: #{e.message}"
        nil
      end

      private

      # Internal helper to extract speaker information (heuristic)
      def extract_speaker(text)
        # Try patterns like "SPEAKER:", "[SPEAKER]", "<v SPEAKER>"
        if (match = text.match(/^\s*<v\s+([^>]+)>/i)) ||
           (match = text.match(/^\s*\[([^\]]+)\]\s*:?/)) ||
           (match = text.match(/^\s*([^:]+):\s+/))
          # Basic cleanup: remove leading/trailing whitespace, potentially trailing colon
          speaker = match[1].strip
          # Avoid matching timestamps as speakers
          return nil if speaker.match?(/^\d+:\d+:\d+/)
          # Avoid matching common sound descriptions as speakers
          return nil if speaker.match?(/^[\[\(].*[\]\)]$/) # e.g., [SOUND], (MUSIC)

          speaker.empty? ? nil : speaker
        end
      end
    end # class SRT
  end # module Parser
end # module MemexRAG
