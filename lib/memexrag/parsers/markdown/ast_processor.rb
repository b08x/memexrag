# llm_memory/parsers/markdown/ast_processor.rb

require 'kramdown' # Ensure Kramdown is available if needed directly
require 'csv'      # Ensure CSV is required for table extraction

module MemexRAG
  module Parser
    class Markdown < Base # Defined within Markdown namespace for clarity
      # This module processes the Kramdown AST (Abstract Syntax Tree)
      # It walks the tree and delegates handling of different node types
      # to specific methods, ultimately producing an array of chunk hashes.
      module AstProcessor
        extend Logging # Make logger available via self.logger

        # Main entry point: Processes the Kramdown root element
        # Returns an array of chunk hashes { content:, metadata: }
        def self.process(root_element)
          chunks = []
          sections_stack = [] # To keep track of current H1/H2 context [{title:, level:}, ...]

          logger.debug "[AST] Starting process with root type: #{root_element&.type}"

          unless root_element&.children && !root_element.children.empty?
            logger.warn '[AST] Root element has no children! Returning empty chunks.'
            return []
          end

          # Iterate through top-level children of the document root
          root_element.children.each do |element|
            process_element(element, sections_stack, chunks)
          end

          logger.debug "[AST] Finished. Generated #{chunks.size} chunks."
          chunks
        end

        # Recursive dispatcher method to process an element based on its type
        # - element: The current Kramdown::Element node
        # - sections_stack: Array tracking current H1/H2 context
        # - chunks: The array where chunk hashes are accumulated
        def self.process_element(element, sections_stack, chunks)
          # logger.debug "[AST] Processing element type: #{element.type}" # Verbose

          case element.type
          when :header
            handle_header(element, sections_stack, chunks)
          when :p, :blockquote, :codeblock, :table, :hr, :img, :a, :dl, :html_element, :math
            # Generic handler for block-level content elements
            handle_content_block(element, sections_stack, chunks)
          when :ul, :ol
            # Specific handler for lists (iterates through list items)
            handle_list(element, sections_stack, chunks)
          when :blank, :xml_comment
            # Ignore blank lines between block elements
            logger.debug "[AST] Skipping element type: #{element.type}" # Optional debug log
          else
            # Log unhandled element types
            logger.warn "[AST] Unhandled element type: #{element.type}"
            # Decide if children of unhandled types should be processed? Usually not for block elements.
          end
        end

        # --- Node Type Handler Methods ---

        # Handles :header elements (H1-H6)
        # Updates the sections_stack for H1/H2, creates chunks for H3+
        def self.handle_header(element, sections_stack, chunks)
          level = element.options[:level]
          # Use element_text helper below to get text content
          title = element_text(element).strip

          if title.empty?
            logger.warn "[AST] Skipping header with empty title (level #{level})."
            return
          end

          # Pop stack entries with level >= current level
          sections_stack.pop while sections_stack.any? && sections_stack.last[:level] >= level

          if level <= 2 # H1 or H2 defines document structure
            sections_stack.push({ title: title, level: level })
            logger.debug "[AST] Updated section stack: #{sections_stack.map { |s| "#{s[:level]}:#{s[:title]}" }.join(' > ')}"
            # Don't add H1/H2 title itself as a chunk, it's structural metadata
          else # H3+ are treated as content chunks
            logger.debug "[AST] Header level #{level} ('#{title}') treated as content chunk."
            # Build metadata including current section/subsection context
            metadata = build_metadata(sections_stack, :"header_#{level}") # Use symbol type
            # Add chunk using SYMBOL keys
            chunks << { content: title, metadata: metadata }
            logger.debug "[AST]   Added H#{level} chunk."
          end
        end

        # Handles :ul and :ol elements by delegating to handle_list_item for children
        def self.handle_list(list_element, sections_stack, chunks)
          logger.debug "[AST] Processing list: #{list_element.type}"
          list_element.children.each do |list_item|
            # Kramdown structure: ul/ol -> li -> p (usually) -> text
            # We process only the :li elements directly
            next unless list_item.type == :li

            handle_list_item(list_item, sections_stack, chunks)
          end
        end

        # Handles :li elements, creating a chunk for each list item
        def self.handle_list_item(item_element, sections_stack, chunks)
          # Use element_text helper to get combined text content of the list item
          item_content = element_text(item_element).strip
          if item_content.empty?
            logger.debug '[AST]   Skipping empty list item.'
            return
          end
          # Build metadata for this list item chunk
          metadata = build_metadata(sections_stack, :li) # Use symbol type :li
          # Add chunk using SYMBOL keys
          chunks << { content: item_content, metadata: metadata }
          logger.debug "[AST]   Added list item chunk (li): #{item_content.slice(0, 50)}"
        end

        # Handles generic block content elements (:p, :blockquote, :codeblock, etc.)
        def self.handle_content_block(element, sections_stack, chunks)
          # Use element_text helper to get text content
          content = element_text(element).strip
          type_symbol = element.type.to_sym # Ensure type is a symbol

          # Skip empty content, except for elements like <hr> or <img> which might be meaningful empty
          # Also skip specific unwanted HTML elements if needed
          if (content.empty? && !%i[hr img].include?(type_symbol)) ||
             (type_symbol == :html_element && element.value.to_s.downcase.include?('<instruction>')) # Example skip
            logger.debug "[AST] Skipping empty or unwanted block: #{type_symbol}"
            return
          end

          # Build metadata for this content chunk
          metadata = build_metadata(sections_stack, type_symbol)
          # Add chunk using SYMBOL keys
          chunks << { content: content, metadata: metadata }
          logger.debug "[AST] Added content chunk: type=#{type_symbol}, preview=#{content.slice(0, 50)}"
        end

        # --- Helper Methods ---

        # Builds the common metadata structure for a chunk based on current context
        def self.build_metadata(sections_stack, type_symbol)
          metadata = { type: type_symbol }
          # Find the current H1 section title from the stack
          section = sections_stack.find { |s| s[:level] == 1 }
          # Find the current H2 subsection title from the stack
          subsection = sections_stack.find { |s| s[:level] == 2 }
          metadata[:section] = section[:title] if section
          metadata[:subsection] = subsection[:title] if subsection
          # Add parser/timestamp info (optional, FileLoader also adds this)
          metadata[:parser] = 'MemexRAG::Parser::Markdown' # Indicate origin
          metadata[:parsed_at] = Time.now.utc.iso8601
          metadata.compact # Remove keys with nil values (like :subsection if none)
        end

        # Extracts text content from a Kramdown element and its children
        # (Moved from original Parser::Markdown)
        def self.element_text(element)
          return '' unless element

          case element.type
          when :text
            element.value || ''
          when :header, :p, :strong, :em, :a, :li, :blockquote, :td, :th
            element.children&.map { |child| element_text(child) }&.join || ''
          when :typographic_sym
            element.value || ''
          # Explicitly handle blank lines - they produce no text output
          when :blank
            ''
          when :codeblock
            lang = element.options[:lang] || ''
            "```#{lang}\n#{element.value&.strip}\n```"
          when :ul, :ol
            list_marker = element.type == :ul ? '* ' : '1. '
            element.children&.select { |c| c.type == :li }&.map { |child| "#{list_marker}#{element_text(child)}" }&.join("\n") || ''
          when :table
            extract_table_content(element)
          when :br
            "\n"
          when :hr
            "\n---\n"
          when :html_element
            element.value || ''
          when :smart_quote
            element.value || ''
          when :img
            alt = element.attr['alt'] || ''
            "![Image: #{alt}]"
          when :codespan
            "`#{element.value}`"
          # Ignored elements (add any others needed)
          when :footnote, :math, :entity, :abbreviation, :xml_comment, :xml_pi, :comment
            ''
          else
            # Default fallback for genuinely unhandled types
            if element.children && !element.children.empty?
              logger.warn "[AST_Text] Unhandled element type in element_text: #{element.type}, processing children."
              element.children.map { |child| element_text(child) }.join
            else
              logger.warn "[AST_Text] Unhandled or empty element type in element_text: #{element.type}."
              ''
            end
          end
        rescue StandardError => e
          logger.error "[AST_Text] Error in element_text for element type #{element&.type}: #{e.message}"
          '' # Return empty string on error
        end

        # Extracts table content into a simpler format (e.g., CSV string)
        # (Moved from original Parser::Markdown)
        def self.extract_table_content(table_node)
          rows = []
          # Iterate through thead, tbody sections
          table_node.children.each do |section|
            next unless %i[thead tbody].include?(section.type)

            # Iterate through tr (table rows)
            section.children.each do |row_node|
              next unless row_node.type == :tr

              row_data = []
              # Iterate through th, td (table cells)
              row_node.children.each do |cell_node|
                next unless %i[th td].include?(cell_node.type)

                # Get cell text, remove internal newlines for simplicity
                row_data << element_text(cell_node).strip.gsub("\n", ' ')
              end
              rows << row_data unless row_data.empty?
            end
          end

          return '' if rows.empty?

          # Convert rows to CSV format string
          begin
            CSV.generate(force_quotes: false) do |csv| # Avoid unnecessary quotes
              rows.each { |row| csv << row }
            end.strip
          rescue StandardError => e
            logger.error "[AST_Table] Error extracting table content as CSV: #{e.message}"
            # Fallback to simple tab/newline format
            rows.map { |row| row.join("\t") }.join("\n")
          end
        end
      end # module AstProcessor
    end # class Markdown
  end # module Parser
end # module MemexRAG
