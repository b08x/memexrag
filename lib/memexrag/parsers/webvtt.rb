# frozen_string_literal: true

module MemexRAG
  module Parser
    class WebVTT < Base # Inherit from Base
      EXTENSIONS = ['.vtt'].freeze
      CONTENT_TYPES = ['text/vtt', 'text/plain'].freeze # Added text/plain as fallback

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
        logger.debug "Initialized WebVTT parser for: #{file_path}"
      end

      # Updated parse method
      def parse
        # File existence check happens in Base#read_file or FileObject init now
        logger.debug "Parsing WebVTT file: #{file_path}"
        begin
          # Use the ::WebVTT parser
          vtt_file = ::WebVTT.read(file_path.to_s) # Pass path string

          @subtitles = [] # Reset subtitles array
          seen_texts = Set.new # To handle potential duplicate cues

          vtt_file.cues.each do |cue|
            original_text = cue.text
            # Basic cleaning: remove HTML-like tags, normalize whitespace
            cleaned_text = original_text.gsub(/<[^>]+>/, '').gsub(/\s+/, ' ').strip

            # Skip empty cues or cues identical to the previous one (after cleaning)
            next if cleaned_text.empty? || seen_texts.include?(cleaned_text)

            seen_texts << cleaned_text

            @subtitles << {
              start_time: cue.start_time_in_seconds,
              end_time: cue.end_time_in_seconds,
              text: cleaned_text,
              speaker: extract_speaker(original_text) # Extract speaker from original text
            }
          end

          # Format output as array of hashes {chunk:, metadata:}
          result_array = @subtitles.map do |sub|
            {
              chunk: sub[:text],
              metadata: { # Only cue-specific metadata
                type: 'cue', # Add type for clarity
                start_time: sub[:start_time],
                end_time: sub[:end_time],
                duration: (sub[:end_time] - sub[:start_time]).round(3), # Calculate duration
                speaker: sub[:speaker] # Include speaker if found
                # Base file metadata (name, size, etc.) will be added by FileLoader
              }.compact # Remove nil values like speaker if not found
            }
          end
          logger.info "Parsed #{result_array.length} unique cues from #{file_path}"
          result_array
        rescue ::WebVTT::MalformedFileError => e
          logger.error "Malformed WebVTT file #{file_path}: #{e.message}"
          [] # Return empty array on parsing error
        rescue Errno::ENOENT => e
          logger.error "WebVTT file not found during parsing: #{file_path} - #{e.message}"
          []
        rescue StandardError => e
          logger.error "Error parsing WebVTT file #{file_path}: #{e.class} - #{e.message}"
          logger.error e.backtrace.first(5).join("\n")
          [] # Return empty array on general error
        end
      end

      private

      # Internal helper to extract speaker information (heuristic) - same as SRT's
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
    end # class WebVTT
  end # module Parser
end # module MemexRAG
