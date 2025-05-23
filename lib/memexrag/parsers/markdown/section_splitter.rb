# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'yaml' # For YAML front matter
require 'json' # For JSON export

# Module to split a Markdown file into sections based on Level 2 headings,
# and then further into subsections based on elements like tables, images, etc.
# It can also export the split content as a JSON string.
module MarkdownSectionSplitter
  # Helper method to extract subsections (text, code blocks, images, etc.)
  # from the content lines of a major (L2) section.
  #
  # @param major_section_lines [Array<String>] Lines of content from the major section.
  # @param major_section_original_start_line_abs [Integer] The absolute line number in the original file
  #                                                      where the first line of major_section_lines started.
  # @param _parent_l2_title [String] The title of the parent L2 section (currently unused but kept for context).
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
      if !current_text_buffer.empty? && current_text_buffer_start_line_rel != -1
        subsections << {
          type: 'text',
          title_suggestion: 'Text Content',
          content_lines: current_text_buffer.dup,
          start_line_in_original: major_section_original_start_line_abs + current_text_buffer_start_line_rel,
          end_line_in_original: major_section_original_start_line_abs + current_processing_line_rel_idx
        }
        current_text_buffer.clear
        current_text_buffer_start_line_rel = -1
      end
    end

    idx = 0
    while idx < major_section_lines.length
      line_content = major_section_lines[idx]
      original_line_num_for_this_line = major_section_original_start_line_abs + idx
      consumed_special_element = false

      # 1. Fenced Code Block
      fence_match = line_content.match(/^```(\w*)$/) || line_content.match(/^~~~ (\w*)$/)
      if fence_match
        add_text_subsection_if_needed.call(idx - 1)
        code_block_lines = [line_content]
        lang = fence_match[1]
        fence_char = line_content.start_with?('```') ? '```' : '~~~'
        code_block_end_idx_rel = idx + 1
        while code_block_end_idx_rel < major_section_lines.length
          code_block_lines << major_section_lines[code_block_end_idx_rel]
          break if major_section_lines[code_block_end_idx_rel].strip == fence_char

          code_block_end_idx_rel += 1
        end
        if code_block_end_idx_rel >= major_section_lines.length || (major_section_lines[code_block_end_idx_rel] && major_section_lines[code_block_end_idx_rel].strip != fence_char)
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

      # 3. Table
      elsif line_content.strip.start_with?('|') && line_content.strip.count('|') >= 2
        table_lines_buffer = []
        table_scan_idx_rel = idx
        while table_scan_idx_rel < major_section_lines.length
          scan_line = major_section_lines[table_scan_idx_rel].strip
          break unless scan_line.start_with?('|') && scan_line.count('|') >= 2

          table_lines_buffer << major_section_lines[table_scan_idx_rel]
          table_scan_idx_rel += 1

        end
        if table_lines_buffer.length >= 1
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
        end

      # 4. Image
      elsif (img_match = line_content.strip.match(/^!\[([^\]]*)\]\(([^\)]+)\)$/))
        add_text_subsection_if_needed.call(idx - 1)
        alt_text = img_match[1]
        subsections << {
          type: 'image',
          title_suggestion: alt_text.empty? ? 'Image' : "Image: #{alt_text}",
          content_lines: [line_content],
          start_line_in_original: original_line_num_for_this_line,
          end_line_in_original: original_line_num_for_this_line
        }
        idx += 1
        consumed_special_element = true

      # 5. Link
      elsif (link_match = line_content.strip.match(/^\[([^\]]+)\]\(([^\)]+)\)$/))
        add_text_subsection_if_needed.call(idx - 1)
        link_text = link_match[1]
        subsections << {
          type: 'link',
          title_suggestion: link_text.empty? ? 'Link' : "Link: #{link_text}",
          content_lines: [line_content],
          start_line_in_original: original_line_num_for_this_line,
          end_line_in_original: original_line_num_for_this_line
        }
        idx += 1
        consumed_special_element = true
      end

      next if consumed_special_element

      current_text_buffer_start_line_rel = idx if current_text_buffer.empty?
      current_text_buffer << line_content
      idx += 1
    end
    add_text_subsection_if_needed.call(major_section_lines.length - 1) unless current_text_buffer.empty?
    subsections
  end

  # Main method to process the Markdown file and create individual section files.
  # This method changes the current working directory.
  public_class_method def self.split_markdown_into_sections(markdown_filepath) # rubocop:disable Metrics/MethodLength
    absolute_markdown_filepath = File.expand_path(markdown_filepath)
    raise ArgumentError, "File not found: #{absolute_markdown_filepath}" unless File.exist?(absolute_markdown_filepath)

    original_basename = File.basename(absolute_markdown_filepath)
    original_content_lines = File.readlines(absolute_markdown_filepath, chomp: false)

    temp_dir_path = Dir.mktmpdir('markdown_sections_')
    # Copy original file into temp_dir for reference, though not strictly used by splitting logic itself
    FileUtils.cp(absolute_markdown_filepath, File.join(temp_dir_path, original_basename))
    Dir.chdir(temp_dir_path) # CRITICAL: Changes CWD

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
            end_line_in_original: current_line_num - 1
          }
        end
        current_l2_section_lines_buffer.clear
        current_l2_section_title = match_l2[1].strip
        current_l2_section_actual_start_line = current_line_num
        current_l2_section_lines_buffer << line
      else
        current_l2_section_lines_buffer << line
      end
    end
    unless current_l2_section_lines_buffer.empty?
      major_sections_data << {
        title: current_l2_section_title,
        content_lines: current_l2_section_lines_buffer,
        start_line_in_original: current_l2_section_actual_start_line,
        end_line_in_original: original_content_lines.length
      }
    end

    return temp_dir_path if major_sections_data.empty?

    major_section_file_idx_counter = 0
    major_sections_data.each do |major_data|
      major_section_file_idx_counter += 1
      subsections = extract_subsections(
        major_data[:content_lines],
        major_data[:start_line_in_original],
        major_data[:title]
      )
      subsection_file_idx_counter = 0
      subsections.each do |sub_data|
        next if sub_data[:content_lines].all? { |line_item| line_item.strip.empty? }

        subsection_file_idx_counter += 1
        formatted_major_idx = format('%03d', major_section_file_idx_counter)
        formatted_sub_idx = format('%03d', subsection_file_idx_counter)
        l2_slug = major_data[:title].downcase.gsub(/\s+/, '-').gsub(/[^\w-]/, '').gsub(/^-+|-+$/, '')
        l2_slug = 'section' if l2_slug.empty?
        sub_slug_suggestion = sub_data[:title_suggestion].downcase.gsub(/\s+/, '-').gsub(/[^\w.:()-]/, '')
        sub_slug_suggestion = 'content' if sub_slug_suggestion.empty?
        max_slug_len = 50
        final_slug_text = "#{l2_slug}-#{sub_slug_suggestion}"
        final_slug_text = final_slug_text[0...max_slug_len] if final_slug_text.length > max_slug_len
        final_slug_text.gsub!(/-+$/, '')
        output_filename_base = "#{formatted_major_idx}-#{formatted_sub_idx}-#{final_slug_text}"
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
    temp_dir_path # Returns the path to the temp directory where files were written
  end

  # New method to split Markdown and export as a JSON string.
  # This method manages the current working directory and cleans up temporary files.
  #
  # @param markdown_filepath [String] Absolute or relative path to the Markdown file.
  # @return [String] A JSON string representing an array of all split sections,
  #                  each with 'metadata' and 'content' keys.
  # @raise [ArgumentError] If the markdown_filepath does not exist.
  public_class_method def self.split_markdown_and_export_as_json(markdown_filepath)
    original_cwd = Dir.pwd
    temp_dir_path = nil # Initialize to ensure it's in scope for ensure block
    json_output_array = []

    begin
      # This call changes Dir.pwd to temp_dir_path
      temp_dir_path = split_markdown_into_sections(markdown_filepath)

      # Operations are now within temp_dir_path
      Dir.glob('*.md').sort.each do |filename|
        file_content_str = File.read(filename)

        # Split YAML front matter from content
        # Regex captures YAML block (non-greedy) and the rest of the content.
        # It expects '---' at the start and end of the YAML block.
        match = file_content_str.match(/\A(---\s*\n.*?\n?)^(---\s*$\n?)(.*)/m)

        if match
          yaml_str = match[1] # The YAML block itself, including the opening ---
          # The content starts after the closing --- and its newline
          content_markdown = match[3] ? match[3].strip : ''

          begin
            metadata = YAML.safe_load(yaml_str)
          rescue Psych::SyntaxError => e
            # Handle malformed YAML in a generated file, or log it
            # For now, we'll store a simple error message in metadata
            puts "Warning: Could not parse YAML for #{filename}: #{e.message}"
            metadata = { 'error' => "YAML parsing error in #{filename}", 'raw_yaml' => yaml_str }
          end
        else
          # No YAML front matter found, treat whole file as content, or handle as error
          # For this implementation, we'll assume files should have front matter.
          # If not, we can adapt. For now, let's log and skip or add with minimal metadata.
          puts "Warning: No YAML front matter detected in #{filename}. Treating as raw content."
          metadata = { 'error' => "No YAML front matter in #{filename}" }
          content_markdown = file_content_str.strip
        end

        json_output_array << { metadata: metadata, content: content_markdown }
      end

      JSON.generate(json_output_array)
    ensure
      # Always change back to the original directory
      Dir.chdir(original_cwd)
      # Clean up the temporary directory if it was created
      FileUtils.remove_entry_secure(temp_dir_path) if temp_dir_path && Dir.exist?(temp_dir_path)
    end
  end

  # Example usage:
  # if __FILE__ == $PROGRAM_NAME
  #   if ARGV.empty?
  #     puts "Usage: ruby markdown_splitter_pro.rb <path_to_markdown_file>"
  #     exit 1
  #   end
  #   input_file = ARGV[0]
  #   begin
  #     # Option 1: Just split files (changes CWD)
  #     # temp_dir = MarkdownSectionSplitter.split_markdown_into_sections(input_file)
  #     # puts "Successfully split sections and subsections into: #{temp_dir}"
  #     # puts "Current working directory: #{Dir.pwd}"
  #     # puts "Files created:"
  #     # Dir.glob("*.md").sort.each { |f| puts "  - #{f}" }
  #     # Dir.chdir("..") # Example: change back if you need to
  #     # FileUtils.remove_entry_secure(temp_dir)
  #
  #     # Option 2: Split and get JSON (manages CWD and cleanup)
  #     json_data = MarkdownSectionSplitter.split_markdown_and_export_as_json(input_file)
  #     puts "Successfully processed Markdown and generated JSON."
  #     puts "Current working directory is back to: #{Dir.pwd}"
  #     # puts "JSON Output:"
  #     # puts JSON.pretty_generate(JSON.parse(json_data)) # For pretty printing
  #
  #     # To save JSON to a file:
  #     output_json_file = File.basename(input_file, ".*") + "_output.json"
  #     File.write(output_json_file, JSON.pretty_generate(JSON.parse(json_data)))
  #     puts "JSON data saved to #{output_json_file}"
  #
  #   rescue ArgumentError => e
  #     puts "Error: #{e.message}"
  #   rescue StandardError => e
  #     puts "An unexpected error occurred: #{e.message}\n#{e.backtrace.join("\n")}"
  #   end
  # end
end
