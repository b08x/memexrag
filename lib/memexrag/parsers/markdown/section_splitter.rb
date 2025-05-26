# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'yaml'
require 'json'

# Main module acting as a facade for splitting Markdown files.
module MarkdownSectionSplitter
  # --- Utility Classes ---

  # Handles file system operations.
  class FileHelper
    def self.read_lines(filepath)
      File.readlines(File.expand_path(filepath), chomp: false)
    end

    def self.basename(filepath)
      File.basename(filepath)
    end

    def self.write_content(filepath, content)
      File.write(filepath, content)
    end

    def self.copy_file(source, dest_dir)
      FileUtils.cp(source, dest_dir)
    end

    def self.expand_path(filepath)
      File.expand_path(filepath)
    end

    def self.file_exist?(filepath)
      File.exist?(filepath)
    end

    # Globs files in a directory, sorts them, and returns paths relative to that directory.
    def self.glob_files(pattern, base_dir: Dir.pwd)
      Dir.chdir(base_dir) { Dir.glob(pattern).sort }
    end

    def self.read_file(filepath)
      File.read(filepath)
    end
  end

  # Manages temporary directories and CWD changes.
  class TempDirManager
    attr_reader :path

    def initialize(prefix = 'markdown_sections_')
      @path = Dir.mktmpdir(prefix)
      @original_cwd = nil
    end

    def chdir_into_temp
      @original_cwd = Dir.pwd
      Dir.chdir(@path)
    end

    def chdir_to_original_and_cleanup
      Dir.chdir(@original_cwd) if @original_cwd && Dir.exist?(@original_cwd)
      FileUtils.remove_entry_secure(@path) if @path && Dir.exist?(@path)
      @path = nil # Prevent double cleanup
    end
  end

  # Handles YAML generation and parsing from strings with front matter.
  class YamlHelper
    def self.generate(data)
      data.to_yaml
    end

    def self.parse_from_string(content_str)
      match = content_str.match(/\A(---\s*\n.*?\n?)^(---\s*$\n?)(.*)/m)
      return [nil, content_str.strip] unless match

      yaml_data_str = match[1]
      markdown_content = match[3] ? match[3].strip : ''
      begin
        [YAML.safe_load(yaml_data_str), markdown_content]
      rescue Psych::SyntaxError => e
        puts "Warning: YAML parsing error: #{e.message}" # Consider a logger
        [{ 'error' => 'YAML parsing error', 'raw_yaml' => yaml_data_str }, markdown_content]
      end
    end
  end

  # Generates slugs and unique filenames for sections.
  class FileNameGenerator
    MAX_SLUG_LEN = 50

    def self.slugify_general(text, fallback = 'content')
      create_slug(text, fallback, /[^\w.:()-]/) # Allow more chars for general slugs
    end

    def self.slugify_l2_title(text, fallback = 'section')
      create_slug(text, fallback, /[^\w-]/) # Stricter for L2 titles in filename
    end

    def self.generate_subsection_filename(major_idx, sub_idx, l2_title, sub_title_suggestion)
      fmt_major = format_index(major_idx)
      fmt_sub = format_index(sub_idx)
      l2_s = slugify_l2_title(l2_title)
      sub_s = slugify_general(sub_title_suggestion)

      base = "#{fmt_major}-#{fmt_sub}-#{truncate_combined_slug("#{l2_s}-#{sub_s}")}"
      find_unique_filename(base, '.md')
    end

    def self.create_slug(text, fallback, remove_regex)
      slug = text.to_s.downcase.gsub(/\s+/, '-').gsub(remove_regex, '').gsub(/^-+|-+$/, '')
      slug.empty? ? fallback : slug
    end

    def self.format_index(index_val)
      format('%03d', index_val)
    end

    def self.truncate_combined_slug(slug_text)
      truncated = slug_text.length > MAX_SLUG_LEN ? slug_text[0...MAX_SLUG_LEN] : slug_text
      truncated.gsub(/-+$/, '')
    end

    def self.find_unique_filename(base, ext)
      candidate = "#{base}#{ext}"
      counter = 1
      # Assumes CWD is the target directory for File.exist? checks
      while File.exist?(candidate)
        candidate = "#{base}-#{counter}#{ext}"
        counter += 1
      end
      candidate
    end
  end

  # --- Data Structures ---
  L2Section = Struct.new(:title, :content_lines, :start_line_in_original, :end_line_in_original)
  Subsection = Struct.new(:type, :title_suggestion, :content_lines, :start_line_in_original, :end_line_in_original, :parent_l2_title)

  # --- Core Logic Classes ---

  # Extracts Level 2 sections from Markdown lines.
  class L2SectionExtractor
    def self.extract(original_lines)
      sections = []
      buffer = []
      current_start_line = 1
      current_title = 'Introduction'

      original_lines.each_with_index do |line, zero_idx|
        current_line_num = zero_idx + 1
        if (match_l2 = line.match(/^## (.*)/))
          add_section_if_buffer_present(sections, current_title, buffer, current_start_line)
          buffer = [line]
          current_title = match_l2[1].strip
          current_start_line = current_line_num
        else
          buffer << line
        end
      end
      add_section_if_buffer_present(sections, current_title, buffer, current_start_line)
      sections
    end

    def self.add_section_if_buffer_present(sections_array, title, line_buffer, start_line)
      return if line_buffer.empty?

      # End line is inclusive, so it's start_line + number_of_lines - 1
      end_line = start_line + line_buffer.count - 1
      sections_array << L2Section.new(title, line_buffer.dup, start_line, end_line)
      line_buffer.clear # Clear buffer for next section
    end
  end

  # Extracts subsections (code, table, text, etc.) from L2 section lines.
  class SubsectionExtractor
    def initialize(major_lines, major_start_abs, parent_l2_title)
      @major_lines = major_lines
      @major_start_abs = major_start_abs # Absolute start line of the first line in @major_lines
      @parent_l2_title = parent_l2_title
      @subsections = []
      @text_buffer = []
      @text_buffer_start_rel = -1
      @current_rel_idx = 0
    end

    def extract
      while @current_rel_idx < @major_lines.length
        line = @major_lines[@current_rel_idx]
        consumed_count = attempt_element_handlers(line)
        @current_rel_idx += if consumed_count > 0
                              consumed_count
                            else
                              (add_to_text_buffer(line)
                               1)
                            end
      end
      flush_text_buffer(@major_lines.length - 1) # Use last line index of major_lines
      @subsections
    end

    private

    def add_to_text_buffer(line)
      @text_buffer_start_rel = @current_rel_idx if @text_buffer.empty?
      @text_buffer << line
    end

    def flush_text_buffer(last_line_idx_in_buffer_rel) # Relative index of the last line included
      return if @text_buffer.empty? || @text_buffer_start_rel == -1

      start_abs = @major_start_abs + @text_buffer_start_rel
      end_abs = @major_start_abs + last_line_idx_in_buffer_rel # End line is inclusive

      @subsections << create_sub('text', 'Text Content', @text_buffer.dup, start_abs, end_abs)
      @text_buffer.clear
      @text_buffer_start_rel = -1
    end

    def create_sub(type, title_sugg, lines, start_abs, end_abs)
      Subsection.new(type, title_sugg, lines, start_abs, end_abs, @parent_l2_title)
    end

    def attempt_element_handlers(current_line)
      [method(:code_block_handler), method(:blockquote_handler), method(:table_handler),
       method(:image_handler), method(:link_handler)].each do |handler|
        subsection, consumed = handler.call(current_line, @current_rel_idx)
        next unless subsection

        # Text buffer ends one line before the special element starts
        flush_text_buffer(@current_rel_idx - 1) if @current_rel_idx > @text_buffer_start_rel && @text_buffer_start_rel != -1
        @subsections << subsection
        return consumed
      end
      0 # No handler consumed lines
    end

    # Individual handlers, each aiming for < 20 lines.
    def code_block_handler(line, rel_idx)
      match = line.match(/^```(\w*)$/) || line.match(/^~~~ (\w*)$/)
      return [nil, 0] unless match

      lines, end_idx = extract_fenced_content(rel_idx, match[0].strip[0, 3])
      lang = match[1]
      title = lang.empty? ? 'Code Block' : "Code Block (#{lang})"
      sub = create_sub('codeblock', title, lines, @major_start_abs + rel_idx, @major_start_abs + end_idx)
      [sub, lines.count]
    end

    def extract_fenced_content(start_rel, fence_str)
      buffer = [@major_lines[start_rel]]
      idx = start_rel + 1
      while idx < @major_lines.length
        buffer << @major_lines[idx]
        break if @major_lines[idx].strip == fence_str

        idx += 1
      end
      # If EOF reached, end_idx is the last line index. Otherwise, it's the closing fence index.
      final_idx = idx < @major_lines.length ? idx : @major_lines.length - 1
      [buffer, final_idx]
    end

    def blockquote_handler(line, rel_idx)
      return [nil, 0] unless line.strip.start_with?('>')

      lines = []
      idx = rel_idx
      while idx < @major_lines.length && @major_lines[idx].strip.start_with?('>')
        lines << @major_lines[idx]
        idx += 1
      end
      return [nil, 0] if lines.empty?

      sub = create_sub('blockquote', 'Blockquote', lines, @major_start_abs + rel_idx, @major_start_abs + idx - 1)
      [sub, lines.count]
    end

    def table_handler(line, rel_idx)
      return [nil, 0] unless line.strip.start_with?('|') && line.count('|') >= 2

      lines = []
      idx = rel_idx
      while idx < @major_lines.length && @major_lines[idx].strip.start_with?('|') && @major_lines[idx].count('|') >= 2
        lines << @major_lines[idx]
        idx += 1
      end
      return [nil, 0] if lines.empty? # Or some minimum line count for a table

      sub = create_sub('table', 'Table', lines, @major_start_abs + rel_idx, @major_start_abs + idx - 1)
      [sub, lines.count]
    end

    def image_handler(line, rel_idx)
      match = line.strip.match(/^!\[([^\]]*)\]\(([^\)]+)\)$/)
      return [nil, 0] unless match

      title = match[1].empty? ? 'Image' : "Image: #{match[1]}"
      sub = create_sub('image', title, [line], @major_start_abs + rel_idx, @major_start_abs + rel_idx)
      [sub, 1]
    end

    def link_handler(line, rel_idx)
      match = line.strip.match(/^\[([^\]]+)\]\(([^\)]+)\)$/)
      return [nil, 0] unless match

      title = match[1].empty? ? 'Link' : "Link: #{match[1]}"
      sub = create_sub('link', title, [line], @major_start_abs + rel_idx, @major_start_abs + rel_idx)
      [sub, 1]
    end
  end

  # --- Public Facade Methods ---

  # Splits Markdown into section files in a temp directory. Changes CWD.
  # Returns the path to the temporary directory.
  def self.split_markdown_into_sections(markdown_filepath)
    abs_path = FileHelper.expand_path(markdown_filepath)
    raise ArgumentError, "File not found: #{abs_path}" unless FileHelper.file_exist?(abs_path)

    original_lines = FileHelper.read_lines(abs_path)
    original_basename = FileHelper.basename(abs_path)

    temp_manager = TempDirManager.new
    temp_manager.chdir_into_temp # CWD is now temp_dir
    FileHelper.copy_file(abs_path, temp_manager.path) # Per original requirement

    process_and_write_all_sections(original_lines, original_basename, temp_manager.path)

    temp_manager.path # Return path; CWD remains temp_dir, no cleanup by this method
  end

  # Splits Markdown and exports all sections as a JSON string.
  # Manages CWD and cleans up temporary files.
  def self.split_markdown_and_export_as_json(markdown_filepath)
    abs_path = FileHelper.expand_path(markdown_filepath)
    raise ArgumentError, "File not found: #{abs_path}" unless FileHelper.file_exist?(abs_path)

    temp_manager = TempDirManager.new
    json_data_array = []
    begin
      temp_manager.chdir_into_temp # CWD is temp_dir
      original_lines = FileHelper.read_lines(abs_path) # Read from original location
      original_basename = FileHelper.basename(abs_path)

      process_and_write_all_sections(original_lines, original_basename, temp_manager.path)

      # Read back generated files from temp_dir for JSON export
      FileHelper.glob_files('*.md', base_dir: temp_manager.path).each do |filename_in_temp|
        full_file_path = File.join(temp_manager.path, filename_in_temp)
        content_str = FileHelper.read_file(full_file_path)
        metadata, content = YamlHelper.parse_from_string(content_str)
        json_data_array << { metadata: metadata, content: content } if metadata
      end
      JSON.generate(json_data_array)
    ensure
      temp_manager.chdir_to_original_and_cleanup # Restores CWD and cleans temp dir
    end
  end

  # Orchestrates sectioning and writing files to the current CWD (expected to be temp_dir).
  def self.process_and_write_all_sections(original_lines, original_basename, _current_temp_dir_path)
    l2_sections = L2SectionExtractor.extract(original_lines)
    return if l2_sections.empty?

    l2_sections.each_with_index do |l2_sec, l2_idx|
      # NOTE: l2_sec.start_line_in_original is the absolute line number of the first line in l2_sec.content_lines
      extractor = SubsectionExtractor.new(l2_sec.content_lines, l2_sec.start_line_in_original, l2_sec.title)
      subsections = extractor.extract
      write_out_subsections(subsections, l2_idx + 1, original_basename, l2_sec.title)
    end
  end

  # Writes individual subsection files to the current CWD.
  def self.write_out_subsections(subsections, l2_file_idx, basename, parent_title)
    subsections.each_with_index do |sub, sub_idx|
      next if sub.content_lines.all? { |ln| ln.strip.empty? } # Skip if all lines are blank

      filename = FileNameGenerator.generate_subsection_filename(
        l2_file_idx, sub_idx + 1, parent_title, sub.title_suggestion
      )
      fm_data = {
        'original_file' => basename, 'parent_section_title' => parent_title,
        'subsection_type' => sub.type, 'title' => sub.title_suggestion,
        'start_line' => sub.start_line_in_original, 'end_line' => sub.end_line_in_original
      }
      file_data = YamlHelper.generate(fm_data) + "---\n" + sub.content_lines.join('')
      FileHelper.write_content(filename, file_data) # Writes to CWD
    end
  end

  # Example usage (commented out):
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
# https://g.co/gemini/share/5da398bf275f
