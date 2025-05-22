# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'yaml' # For YAML front matter

# Module to split a Markdown file into sections based on Level 2 headings.
module MarkdownSectionSplitter
  # Processes a Markdown file:
  # 1. Copies it to a temporary directory.
  # 2. Changes the current working directory to this temporary directory.
  # 3. Splits the Markdown content by Level 2 headings (##).
  # 4. For each section, creates a new .md file in the temporary directory.
  #    The filename will be prefixed with a zero-padded index (e.g., "001-introduction.md").
  # 5. Inserts YAML front matter into each new file, including:
  #    - original_file: The basename of the input file.
  #    - title: The text of the Level 2 heading for that section (or "Introduction").
  #    - start_line: The starting line number of this section in the original file.
  #    - end_line: The ending line number of this section in the original file.
  #
  # @param markdown_filepath [String] Absolute or relative path to the Markdown file.
  # @return [String] The path to the temporary directory where files were created
  #                  and into which the current directory has been changed.
  # @raise [ArgumentError] If the markdown_filepath does not exist.
  #
  # @note This method changes the current working directory (`Dir.pwd`) of the Ruby process
  #       to the created temporary directory, as per the requirements.
  #       The caller should be aware of this side effect.
  def self.split_markdown_into_sections(markdown_filepath)
    absolute_markdown_filepath = File.expand_path(markdown_filepath)
    raise ArgumentError, "File not found: #{absolute_markdown_filepath}" unless File.exist?(absolute_markdown_filepath)

    original_basename = File.basename(absolute_markdown_filepath)
    # Read all lines from the original file, preserving line endings for accurate content reconstruction.
    # These line numbers are crucial for the YAML front matter.
    original_content_lines = File.readlines(absolute_markdown_filepath, chomp: false)

    # 1. Create a temporary directory
    temp_dir_path = Dir.mktmpdir('markdown_sections_')

    # 2. Copy the original file to the temp dir
    copied_file_in_temp_dir_path = File.join(temp_dir_path, original_basename)
    FileUtils.cp(absolute_markdown_filepath, copied_file_in_temp_dir_path)

    # 3. Change into the tempdir
    Dir.chdir(temp_dir_path)

    # --- Sectioning Logic ---
    sections = []
    current_section_lines_buffer = []
    current_section_actual_start_line = 1
    current_section_title = 'Introduction' # Default for content before first L2 or if no L2s

    original_content_lines.each_with_index do |line_content, zero_based_index|
      current_line_number_in_original = zero_based_index + 1
      match_data = line_content.match(/^## (.*)/)

      if match_data
        unless current_section_lines_buffer.empty?
          previous_section_end_line = current_line_number_in_original - 1
          sections << {
            title: current_section_title,
            content_lines: current_section_lines_buffer.dup,
            start_line_in_original: current_section_actual_start_line,
            end_line_in_original: previous_section_end_line
          }
          current_section_lines_buffer.clear
        end

        current_section_title = match_data[1].strip
        current_section_actual_start_line = current_line_number_in_original
        current_section_lines_buffer << line_content
      else
        current_section_lines_buffer << line_content
      end
    end

    unless current_section_lines_buffer.empty?
      sections << {
        title: current_section_title,
        content_lines: current_section_lines_buffer,
        start_line_in_original: current_section_actual_start_line,
        end_line_in_original: original_content_lines.length
      }
    end

    if original_content_lines.empty? && sections.empty?
      return temp_dir_path # Return path to the (empty) temp dir.
    end

    # --- File Writing Logic ---
    created_files_info = []
    section_file_index = 0 # Initialize index for filename prefix

    sections.each do |section_data|
      section_file_index += 1 # Increment for each section (1-based for filenames)
      # Format index with leading zeros (e.g., 001, 002, ... 010, 011 ... 100, 101)
      formatted_index = format('%03d', section_file_index)

      slug_base = section_data[:title]
                  .downcase
                  .gsub(/\s+/, '-')
                  .gsub(/[^\w-]/, '')
                  .gsub(/^-+|-+$/, '')
      slug_base = 'section' if slug_base.empty?

      # Construct the base filename part, including the formatted index
      # e.g., "001-introduction" or "002-my-topic"
      output_filename_base = "#{formatted_index}-#{slug_base}"

      # Initial candidate for the filename
      output_filename_candidate = "#{output_filename_base}.md"

      # Handle potential collisions (though less likely with the index prefix)
      # If "001-introduction.md" exists, try "001-introduction-1.md", etc.
      collision_counter = 1
      final_output_filename = output_filename_candidate # Start with the initial candidate

      # Check for existence in the current directory (which is temp_dir_path)
      while File.exist?(final_output_filename)
        final_output_filename = "#{output_filename_base}-#{collision_counter}.md"
        collision_counter += 1
      end

      front_matter_hash = {
        'original_file' => original_basename,
        'title' => section_data[:title],
        'start_line' => section_data[:start_line_in_original],
        'end_line' => section_data[:end_line_in_original]
      }
      yaml_front_matter = front_matter_hash.to_yaml

      file_content_string = yaml_front_matter + "---\n" + section_data[:content_lines].join('')

      File.write(final_output_filename, file_content_string)
      created_files_info << { filename: final_output_filename, original_title: section_data[:title] }
    end

    temp_dir_path
  end

  # Example usage (can be placed outside the module or in a separate script):
  # if __FILE__ == $PROGRAM_NAME
  #   if ARGV.empty?
  #     puts "Usage: ruby markdown_splitter.rb <path_to_markdown_file>"
  #     exit 1
  #   end
  #
  #   input_file = ARGV[0]
  #
  #   begin
  #     puts "Processing #{input_file}..."
  #     # This will change the current directory:
  #     temp_directory = MarkdownSectionSplitter.split_markdown_into_sections(input_file)
  #
  #     puts "Successfully split sections into: #{temp_directory}"
  #     puts "Current working directory is now: #{Dir.pwd}"
  #     puts "Files created in temp directory:"
  #     Dir.glob("*.md").sort.each do |filename| # List .md files in the new CWD, sorted
  #       puts "  - #{filename}"
  #     end
  #
  #     # To inspect a file's content:
  #     # first_created_file = Dir.glob("*.md").sort.first
  #     # if first_created_file
  #     #   puts "\nContent of #{first_created_file}:"
  #     #   puts File.read(first_created_file)
  #     # end
  #
  #   rescue ArgumentError => e
  #     puts "Error: #{e.message}"
  #     exit 1
  #   rescue StandardError => e
  #     puts "An unexpected error occurred: #{e.message}"
  #     puts e.backtrace.join("\n")
  #     exit 1
  #   end
  # end
end
