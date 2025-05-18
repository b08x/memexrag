# llm_memory/parsers/markdown.rb
require_relative 'base'
require_relative 'markdown/ast_processor' # Require the new module
require 'kramdown'
require 'yaml'
# Removed CSV require if table extraction logic moved to AstProcessor

module MemexRAG
  module Parser
    class Markdown < Base
      EXTENSIONS = ['.markdown', '.md'].freeze
      CONTENT_TYPES = ['text/markdown', 'text/plain'].freeze

      attr_reader :frontmatter

      def self.handles?(file_path)
        super(file_path, EXTENSIONS, CONTENT_TYPES)
      end

      # Initialize still handles frontmatter extraction
      def initialize(file_object)
        super
        logger.debug "Initialized Markdown parser for: #{file_path}"
        @frontmatter = {}
        @content_without_frontmatter = read_file # Read full content once

        # Regex to find and extract YAML frontmatter (same as before)
        frontmatter_regex = /\A---\s*?\n(.*?)\n---\s*?\n?/m
        if (match = frontmatter_regex.match(@content_without_frontmatter))
          yaml_text = match[1]
          @content_without_frontmatter = match.post_match.strip
          begin
            # ...(YAML parsing logic as before)...
            yaml_data = YAML.safe_load(yaml_text, permitted_classes: [Date, Time], aliases: true) || {}
            @frontmatter = yaml_data if yaml_data.is_a?(Hash)
            logger.debug 'YAML Frontmatter parsed during initialization.'
          rescue Psych::SyntaxError => e
            logger.warn "Failed to parse YAML frontmatter during init (Syntax Error): #{e.message}"
            @frontmatter = { yaml_error: "Syntax error: #{e.message}" }
          rescue StandardError => e
            logger.warn "Failed to parse YAML frontmatter during init (General Error): #{e.message}"
            @frontmatter = { yaml_error: "Parse error: #{e.message}" }
          end
        else
          logger.debug 'No YAML frontmatter found during initialization.'
        end
      end

      # Parse method is now much simpler
      def parse
        logger.debug "Starting parsing for: #{file_path}"
        chunks = []
        begin
          # 1. Use Kramdown to get the AST root
          kramdown_options = {
            input: :GFM, hard_wrap: false, auto_ids: true, footnote_nr: 1,
            show_warnings: true, smart_quotes: %w[apos apos quot quot], syntax_highlighter: nil
          }
          doc = Kramdown::Document.new(@content_without_frontmatter, kramdown_options)

          # 2. Delegate AST processing to the AstProcessor module
          chunks = AstProcessor.process(doc.root) # Call the processor
        rescue StandardError => e
          logger.error "Error during Markdown parsing pipeline at #{file_path}: #{e.class} - #{e.message}"
          logger.error e.backtrace.join("\n")
          # Return empty array on error
        end
        logger.debug("Parsing complete, returning #{chunks.size} chunks.")
        chunks # Return the array of chunks directly
      end

      # Private methods process, format_for_rag, process_sections, process_X_chunks are now removed
      # The element_text and extract_table_content logic needs to be moved
      # into AstProcessor or a shared utility module.

      # private
      #   def process(...) -> Removed
      #   def format_for_rag(...) -> Removed (Structure built by AstProcessor)
      #   def process_sections(...) -> Moved and refactored into AstProcessor
      #   def process_section_chunks(...) -> Logic incorporated into AstProcessor handlers
      #   def process_subsection_chunks(...) -> Logic incorporated into AstProcessor handlers
      #   def element_text(...) -> Moved to AstProcessor (or utility)
      #   def extract_table_content(...) -> Moved to AstProcessor (or utility)
    end # class Markdown
  end # module Parser
end # module MemexRAG
