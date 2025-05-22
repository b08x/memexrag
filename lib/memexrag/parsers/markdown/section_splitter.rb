# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'yaml' # For YAML front matter

# Module to split a Markdown file into sections based on Level 2 headings,
# and then further into subsections based on elements like tables, images, etc.
module MarkdownSectionSplitter
  # Helper method to extract subsections (text, code blocks, images, etc.)
  # from the content lines of a major (L2) section.
  #
  # @param major_section_lines [Array<String>] Lines of content from the major section.
  # @param major_section_original_start_line_abs [Integer] The absolute line number in the original file
  #                                                      where the first line of major_section_lines started.
  # @param parent_l2_title [String] The title of the parent L2 section.
  # @return [Array<Hash>] An array of subsection data hashes. Each hash contains:
  #                       :type (String), :title_suggestion (String), :content_lines (Array<String>),
  #                       :start_line_in_original (Integer), :end_line_in_original (Integer).
  private_class_method def self.extract_subsections(major_section_lines, major_section_original_start_line_abs, _parent_l2_title) # rubocop:disable Metrics/MethodLength
    subsections = []
    current_text_buffer = []
    # Relative start line index of the current_text_buffer within major_section_lines
    current_text_buffer_start_line_rel = -1

    # Lambda to flush the current text buffer into a new subsection
    add_text_subsection_if_needed = lambda do |current_processing_line_rel_idx|
      # current_processing_line_rel_idx is the relative index of the line *before* a special element,
      # or the last line index of the major section if called at the end.
      if !current_text_buffer.empty? && current_text_buffer_start_line_rel != -1
        subsections << {
          type: 'text',
          title_suggestion: 'Text Content', # Generic title, to be combined for slug
          content_lines: current_text_buffer.dup,
          start_line_in_original: major_section_original_start_line_abs + current_text_buffer_start_line_rel,
          end_line_in_original: major_section_original_start_line_abs + current_processing_line_rel_idx
        }
        current_text_buffer.clear
        current_text_buffer_start_line_rel = -1 # Reset
      end
    end

    idx = 0 # Current relative line index within major_section_lines
    while idx < major_section_lines.length
      line_content = major_section_lines[idx]
      original_line_num_for_this_line = major_section_original_start_line_abs + idx
      consumed_special_element = false

      # 1. Fenced Code Block
      fence_match = line_content.match(/^```(\w*)$/) || line_content.match(/^~~~ (\w*)$/)
      if fence_match
        add_text_subsection_if_needed.call(idx - 1) # Finalize text before this block

        code_block_lines = [line_content]
        lang = fence_match[1]
        fence_char = line_content.start_with?('```') ? '```' : '~~~'

        code_block_end_idx_rel = idx + 1
        while code_block_end_idx_rel < major_section_lines.length
          code_block_lines << major_section_lines[code_block_end_idx_rel]
          break if major_section_lines[code_block_end_idx_rel].strip == fence_char

          code_block_end_idx_rel += 1
        end
        # Ensure the block is properly terminated, even if EOF is hit
        if code_block_end_idx_rel >= major_section_lines.length || major_section_lines[code_block_end_idx_rel].strip != fence_char
          code_block_end_idx_rel = [code_block_end_idx_rel,
                                    major_section_lines.length - 1].min
        end

        subsections << {
          type: 'codeblock',
          title_suggestion: lang.empty? ? 'Code Block' : "Code Block (#{lang})",
          content_lines: code_block_lines,
          start_line_in_original: original_line_num_for_this_line,
          end_line_in_original: major_section_original_start_line_abs + code_block_end_idx_rel
        }
        idx = code_block_end_idx_rel + 1
        consumed_special_element = true

      # 2. Blockquote
      elsif line_content.strip.start_with?('>')
        add_text_subsection_if_needed.call(idx - 1)

        blockquote_lines = []
        blockquote_start_idx_rel = idx
        while blockquote_start_idx_rel < major_section_lines.length && major_section_lines[blockquote_start_idx_rel].strip.start_with?('>')
          blockquote_lines << major_section_lines[blockquote_start_idx_rel]
          blockquote_start_idx_rel += 1
        end

        subsections << {
          type: 'blockquote',
          title_suggestion: 'Blockquote',
          content_lines: blockquote_lines,
          start_line_in_original: original_line_num_for_this_line,
          end_line_in_original: major_section_original_start_line_abs + blockquote_start_idx_rel - 1
        }
        idx = blockquote_start_idx_rel
        consumed_special_element = true

      # 3. Table (contiguous lines starting with '|' and having at least two '|')
      elsif line_content.strip.start_with?('|') && line_content.strip.count('|') >= 2
        # Check if it's potentially a table block # Assume current line is

        # Look ahead to gather all table lines
        table_lines_buffer = []
        table_scan_idx_rel = idx
        while table_scan_idx_rel < major_section_lines.length
          scan_line = major_section_lines[table_scan_idx_rel].strip
          break unless scan_line.start_with?('|') && scan_line.count('|') >= 2

          table_lines_buffer << major_section_lines[table_scan_idx_rel] # Store original line
          table_scan_idx_rel += 1

          # Non-table line found

        end

        # A table should ideally have at least 2 lines (e.g. header + separator, or header + data)
        if table_lines_buffer.length >= 1 # Adjusted to 1 for simple tables like just a separator or one row
          add_text_subsection_if_needed.call(idx - 1)

          subsections << {
            type: 'table',
            title_suggestion: 'Table',
            content_lines: table_lines_buffer,
            start_line_in_original: original_line_num_for_this_line,
            end_line_in_original: major_section_original_start_line_abs + table_scan_idx_rel - 1
          }
          idx = table_scan_idx_rel
          consumed_special_element = true
        else
          # Not a table block by this heuristic, will fall through to text
          false
        end
      # If !current_line_is_table_material, it will be handled by the text accumulation logic below

      # 4. Image (standalone on a line, after stripping whitespace)
      # Example: `  ![alt text](url)  `
      elsif (img_match = line_content.strip.match(/^!\[([^\]]*)\]\(([^\)]+)\)$/))
        add_text_subsection_if_needed.call(idx - 1)
        alt_text = img_match[1]
        subsections << {
          type: 'image',
          title_suggestion: alt_text.empty? ? 'Image' : "Image: #{alt_text}",
          content_lines: [line_content], # Original line with its whitespace
          start_line_in_original: original_line_num_for_this_line,
          end_line_in_original: original_line_num_for_this_line
        }
        idx += 1
        consumed_special_element = true

      # 5. Link (standalone on a line, after stripping whitespace)
      # Example: `  [link text](url)  `
      elsif (link_match = line_content.strip.match(/^\[([^\]]+)\]\(([^\)]+)\)$/))
        add_text_subsection_if_needed.call(idx - 1)
        link_text = link_match[1]
        subsections << {
          type: 'link',
          title_suggestion: link_text.empty? ? 'Link' : "Link: #{link_text}",
          content_lines: [line_content], # Original line
          start_line_in_original: original_line_num_for_this_line,
          end_line_in_original: original_line_num_for_this_line
        }
        idx += 1
        consumed_special_element = true
      end

      # If no special element was consumed, add to current text buffer
      next if consumed_special_element

      current_text_buffer_start_line_rel = idx if current_text_buffer.empty?
      current_text_buffer << line_content
      idx += 1
    end

    # Add any remaining text in the buffer as the last subsection
    add_text_subsection_if_needed.call(major_section_lines.length - 1) unless current_text_buffer.empty?

    subsections
  end

  # Main method to process the Markdown file.
  public_class_method def self.split_markdown_into_sections(markdown_filepath) # rubocop:disable Metrics/MethodLength
    absolute_markdown_filepath = File.expand_path(markdown_filepath)
    raise ArgumentError, "File not found: #{absolute_markdown_filepath}" unless File.exist?(absolute_markdown_filepath)

    original_basename = File.basename(absolute_markdown_filepath)
    original_content_lines = File.readlines(absolute_markdown_filepath, chomp: false)

    temp_dir_path = Dir.mktmpdir('markdown_sections_')
    copied_file_in_temp_dir_path = File.join(temp_dir_path, original_basename) # Keep original for reference if needed
    FileUtils.cp(absolute_markdown_filepath, copied_file_in_temp_dir_path)
    Dir.chdir(temp_dir_path)

    # --- Major Sectioning Logic (L2 headings) ---
    major_sections_data = []
    current_l2_section_lines_buffer = []
    current_l2_section_actual_start_line = 1
    current_l2_section_title = 'Introduction'

    original_content_lines.each_with_index do |line, zero_based_idx|
      current_line_num = zero_based_idx + 1
      match_l2 = line.match(/^## (.*)/)

      if match_l2
        unless current_l2_section_lines_buffer.empty?
          major_sections_data << {
            title: current_l2_section_title,
            content_lines: current_l2_section_lines_buffer.dup,
            start_line_in_original: current_l2_section_actual_start_line,
            # End line is the line *before* the current L2 heading
            end_line_in_original: current_line_num - 1
          }
        end
        current_l2_section_lines_buffer.clear
        current_l2_section_title = match_l2[1].strip
        current_l2_section_actual_start_line = current_line_num
        current_l2_section_lines_buffer << line # Add L2 heading line to its section
      else
        current_l2_section_lines_buffer << line
      end
    end

    # Add the last accumulated L2 section
    unless current_l2_section_lines_buffer.empty?
      major_sections_data << {
        title: current_l2_section_title,
        content_lines: current_l2_section_lines_buffer,
        start_line_in_original: current_l2_section_actual_start_line,
        end_line_in_original: original_content_lines.length
      }
    end

    return temp_dir_path if major_sections_data.empty? # Handle empty or no-L2-heading files gracefully

    # --- File Writing Logic (Iterating Major and Subsections) ---
    major_section_file_idx_counter = 0

    major_sections_data.each do |major_data|
      major_section_file_idx_counter += 1

      subsections = extract_subsections(
        major_data[:content_lines],
        major_data[:start_line_in_original], # This is the absolute start line of the first line in major_data[:content_lines]
        major_data[:title]
      )

      subsection_file_idx_counter = 0
      subsections.each do |sub_data|
        # Corrected line:
        next if sub_data[:content_lines].all? { |line_item| line_item.strip.empty? } # Skip empty subsections

        subsection_file_idx_counter += 1

        formatted_major_idx = format('%03d', major_section_file_idx_counter)
        formatted_sub_idx = format('%03d', subsection_file_idx_counter)

        # Create slug from L2 title and subsection title suggestion
        l2_slug = major_data[:title].downcase.gsub(/\s+/, '-').gsub(/[^\w-]/, '').gsub(/^-+|-+$/, '')
        l2_slug = 'section' if l2_slug.empty?

        sub_slug_suggestion = sub_data[:title_suggestion].downcase.gsub(/\s+/, '-').gsub(/[^\w.:()-]/, '') # Allow more chars in sub slug
        sub_slug_suggestion = 'content' if sub_slug_suggestion.empty?

        # Truncate long slugs to avoid excessively long filenames
        max_slug_len = 50
        final_slug_text = "#{l2_slug}-#{sub_slug_suggestion}"
        final_slug_text = final_slug_text[0...max_slug_len] if final_slug_text.length > max_slug_len
        final_slug_text.gsub!(/-+$/, '') # Remove trailing hyphens after truncation

        output_filename_base = "#{formatted_major_idx}-#{formatted_sub_idx}-#{final_slug_text}"

        # Filename collision handling
        output_filename_candidate = "#{output_filename_base}.md"
        collision_counter = 1
        final_output_filename = output_filename_candidate
        while File.exist?(final_output_filename)
          final_output_filename = "#{output_filename_base}-#{collision_counter}.md"
          collision_counter += 1
        end

        front_matter = {
          'original_file' => original_basename,
          'parent_section_title' => major_data[:title],
          'subsection_type' => sub_data[:type],
          'title' => sub_data[:title_suggestion],
          'start_line' => sub_data[:start_line_in_original],
          'end_line' => sub_data[:end_line_in_original]
        }.to_yaml

        file_content = front_matter + "---\n" + sub_data[:content_lines].join('')
        File.write(final_output_filename, file_content)
      end
    end
    temp_dir_path
  end

  # Example usage:
  # if __FILE__ == $PROGRAM_NAME
  #   if ARGV.empty?
  #     puts "Usage: ruby markdown_splitter_pro.rb <path_to_markdown_file>"
  #     exit 1
  #   end
  #   input_file = ARGV[0]
  #   begin
  #     temp_dir = MarkdownSectionSplitter.split_markdown_into_sections(input_file)
  #     puts "Successfully split sections and subsections into: #{temp_dir}"
  #     puts "Current working directory: #{Dir.pwd}"
  #     puts "Files created:"
  #     Dir.glob("*.md").sort.each { |f| puts "  - #{f}" }
  #   rescue ArgumentError => e
  #     puts "Error: #{e.message}"
  #   rescue StandardError => e
  #     puts "An unexpected error occurred: #{e.message}\n#{e.backtrace.join("\n")}"
  #   end
  # end
end
