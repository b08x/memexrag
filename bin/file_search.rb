#!/usr/bin/env ruby

require 'tty-prompt'
require 'tty-box'
require 'tty-screen'
require 'tty-which'
require 'open4'
require 'fileutils'
require 'tempfile'

class FileExplorerCLI
  def initialize
    @prompt = TTY::Prompt.new
    @width = TTY::Screen.width
    @height = TTY::Screen.height

    # Check for required dependencies
    check_dependencies
  end

  def check_dependencies
    dependencies = %w[fd fzf rga bat file]
    missing = dependencies.reject { |cmd| TTY::Which.exist?(cmd) }

    unless missing.empty?
      puts 'Error: The following required dependencies are missing:'
      missing.each { |cmd| puts "  - #{cmd}" }
      puts "\nPlease install them and try again."
      exit 1
    end

    # Optional dependencies
    optionals = { 'timg' => 'image preview', 'pdftotext' => 'PDF preview', 'ranger' => 'file browsing', 'code' => 'VS Code integration' }
    missing_optionals = optionals.keys.reject { |cmd| TTY::Which.exist?(cmd) }

    return if missing_optionals.empty?

    puts 'Note: The following optional dependencies are missing:'
    missing_optionals.each { |cmd| puts "  - #{cmd} (#{optionals[cmd]})" }
    puts "\nYou can still use the application, but some features may be limited."
    sleep 2
  end

  def run
    loop do
      clear_screen
      display_header

      choices = [
        { name: '📁 Find files by type', value: :find_files },
        { name: '🔍 Search file contents', value: :search_contents },
        { name: '⚙️  Configuration', value: :configuration },
        { name: '❓ Help', value: :help },
        { name: '👋 Exit', value: :exit }
      ]

      choice = @prompt.select('What would you like to do?', choices, cycle: true)

      case choice
      when :find_files
        find_files
      when :search_contents
        search_contents
      when :configuration
        configuration
      when :help
        display_help
      when :exit
        clear_screen
        exit 0
      end
    end
  end

  def display_header
    box = TTY::Box.frame(
      width: @width,
      title: { top_left: ' 📂 File Explorer CLI ', bottom_right: ' v0.1.0 ' },
      style: {
        fg: :bright_white,
        bg: :blue,
        border: { fg: :bright_blue }
      }
    ) do
      'An interactive file explorer for the command line'
    end

    puts box
  end

  def clear_screen
    system('clear') || system('cls')
  end

  def execute_command(cmd)
    status = 0
    outstr = ''
    errstr = ''

    Open4.popen4(cmd) do |pid, _stdin, stdout, stderr|
      outstr = stdout.read.strip
      errstr = stderr.read.strip
      _, status = Process.waitpid2(pid)
    end

    unless status.success?
      @prompt.error("Command failed: #{cmd}")
      @prompt.error(errstr) unless errstr.empty?
      @prompt.keypress('Press any key to continue...')
    end

    [outstr, errstr, status]
  end

  def find_files
    search_dir = @prompt.ask('Directory to search in:', default: '.')
    return unless search_dir && Dir.exist?(search_dir)

    file_types = [
      { name: 'All files', value: '' },
      { name: 'Ruby files (.rb)', value: '-e .rb' },
      { name: 'JavaScript files (.js)', value: '-e .js' },
      { name: 'Text files (.txt)', value: '-e .txt' },
      { name: 'PDF files (.pdf)', value: '-e .pdf' },
      { name: 'Image files (.jpg, .png, etc.)', value: '-e .jpg -e .jpeg -e .png -e .gif' },
      { name: 'Custom extension...', value: :custom }
    ]

    file_type = @prompt.select('What type of files are you looking for?', file_types)

    if file_type == :custom
      extension = @prompt.ask("Enter file extension (with dot, e.g. '.rb'):")
      return unless extension

      file_type = "-e #{extension}"
    end

    fd_command = "fd -t f #{file_type} . #{search_dir}"

    # Generate FZF preview command based on file type
    preview_cmd = generate_preview_command

    # Call FZF with the preview command
    fzf_command = "#{fd_command} | fzf --preview='#{preview_cmd}' --preview-window='right:60%' " +
                  "--bind='ctrl-/:change-preview-window(down|hidden|)' " +
                  "--bind='ctrl-o:execute(code {})' " +
                  "--bind='ctrl-r:execute(ranger $(dirname {}))' " +
                  "--header='ESC: exit, CTRL+/: toggle preview, CTRL+O: open in VS Code, CTRL+R: open in ranger'"

    selected_file = `#{fzf_command}`.chomp

    return unless selected_file && !selected_file.empty?

    process_selected_file(selected_file)
  end

  def search_contents
    search_dir = @prompt.ask('Directory to search in:', default: '.')
    return unless search_dir && Dir.exist?(search_dir)

    search_pattern = @prompt.ask('Search pattern:')
    return unless search_pattern && !search_pattern.empty?

    rga_command = "rga --no-messages --vimgrep '#{search_pattern}' #{search_dir}"

    # Generate temporary file for displaying rga results in FZF
    temp_file = Tempfile.new('file_explorer_rga')
    begin
      `#{rga_command} > #{temp_file.path}`

      if File.size(temp_file.path) == 0
        @prompt.say('No results found.')
        @prompt.keypress('Press any key to continue...')
        return
      end

      # Format for FZF display
      format_cmd = "cat #{temp_file.path} | awk -F: '{print $1\":\"$2\":\"$3\":\"$4}'"

      # Generate preview command for search results
      preview_cmd = 'bat --style=numbers --color=always {1} --highlight-line {2}'

      fzf_command = "#{format_cmd} | fzf --delimiter=: " +
                    "--preview='#{preview_cmd}' " +
                    "--preview-window='right:60%' " +
                    "--bind='ctrl-/:change-preview-window(down|hidden|)' " +
                    "--bind='ctrl-o:execute(code {1})' " +
                    "--bind='ctrl-r:execute(kitty -e ranger $(dirname {1}))' " +
                    "--header='ESC: exit, CTRL+/: toggle preview, CTRL+O: open in VS Code, CTRL+R: open in ranger'"

      selected_result = `#{fzf_command}`.chomp

      if selected_result && !selected_result.empty?
        file_path, line_number = selected_result.split(':', 2)
        process_selected_file(file_path, line_number.to_i)
      end
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  def generate_preview_command
    <<~PREVIEW
      if file --mime-type {} | grep -q "text/"; then
        bat --style=numbers --color=always {}
      elif file --mime-type {} | grep -q "image/"; then
        if #{TTY::Which.exist?('timg') ? 'true' : 'false'}; then
          timg {}
        else
          file {}
        fi
      elif file --mime-type {} | grep -q "application/pdf"; then
        if #{TTY::Which.exist?('pdftotext') ? 'true' : 'false'}; then
          pdftotext {} - | head -500
        else
          file {}
        fi
      else
        file {}
      fi
    PREVIEW
  end

  def process_selected_file(file_path, line_number = nil)
    return unless File.exist?(file_path)

    actions = [
      { name: "Open with $EDITOR (#{ENV['EDITOR'] || 'vi'})", value: :editor },
      { name: 'Open with VS Code', value: :vscode },
      { name: 'Open containing folder with Ranger', value: :ranger },
      { name: 'Open containing folder with VS Code', value: :vscode_dir },
      { name: 'Search within this file', value: :search_within },
      { name: 'Back to main menu', value: :back }
    ]

    choice = @prompt.select("Action for: #{file_path}", actions, per_page: 10)

    case choice
    when :editor
      editor = ENV['EDITOR'] || 'vi'
      line_cmd = line_number ? "+#{line_number}" : ''
      execute_command("#{editor} #{line_cmd} '#{file_path}'")
    when :vscode
      line_cmd = line_number ? ":#{line_number}" : ''
      execute_command("code '#{file_path}#{line_cmd}'")
    when :ranger
      execute_command("ranger '#{File.dirname(file_path)}'")
    when :vscode_dir
      execute_command("code '#{File.dirname(file_path)}'")
    when :search_within
      search_within_file(file_path)
    when :back
      nil
    end
  end

  def search_within_file(file_path)
    search_pattern = @prompt.ask('Search pattern:')
    return unless search_pattern && !search_pattern.empty?

    rga_command = "rga --no-messages --vimgrep '#{search_pattern}' '#{file_path}'"

    # Generate temporary file for results
    temp_file = Tempfile.new('file_explorer_search_within')
    begin
      `#{rga_command} > #{temp_file.path}`

      if File.size(temp_file.path) == 0
        @prompt.say('No results found.')
        @prompt.keypress('Press any key to continue...')
        return
      end

      # Format for FZF display
      format_cmd = "cat #{temp_file.path} | awk -F: '{print $1\":\"$2\":\"$3\":\"$4}'"

      # Generate preview command for search results
      preview_cmd = "bat --style=numbers --color=always #{file_path} --highlight-line {2}"

      fzf_command = "#{format_cmd} | fzf --delimiter=: " +
                    "--preview='#{preview_cmd}' " +
                    "--preview-window='right:60%' " +
                    "--bind='ctrl-/:change-preview-window(down|hidden|)' " +
                    "--header='ESC: exit, CTRL+/: toggle preview'"

      selected_line = `#{fzf_command}`.chomp

      if selected_line && !selected_line.empty?
        _, line_number = selected_line.split(':', 2)
        process_selected_file(file_path, line_number.to_i)
      end
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  def configuration
    choices = [
      { name: 'Show current configuration', value: :show },
      { name: 'Back to main menu', value: :back }
    ]

    choice = @prompt.select('Configuration Options', choices)

    case choice
    when :show
      show_configuration
    when :back
      nil
    end
  end

  def show_configuration
    config_info = [
      "Terminal size: #{@width}×#{@height}",
      "EDITOR: #{ENV['EDITOR'] || 'Not set (will use vi)'}"
    ]

    # Check for optional dependencies
    config_info << "\nOptional dependencies:"
    config_info << "timg (image preview): #{TTY::Which.exist?('timg') ? '✓' : '✗'}"
    config_info << "pdftotext (PDF preview): #{TTY::Which.exist?('pdftotext') ? '✓' : '✗'}"
    config_info << "ranger (file browsing): #{TTY::Which.exist?('ranger') ? '✓' : '✗'}"
    config_info << "code (VS Code): #{TTY::Which.exist?('code') ? '✓' : '✗'}"

    box = TTY::Box.frame(
      title: { top_left: ' Configuration ' },
      width: @width - 4,
      padding: 1
    ) do
      config_info.join("\n")
    end

    puts box
    @prompt.keypress('Press any key to continue...')
  end

  def display_help
    help_text = <<-HELP
    File Explorer CLI Help

    This application allows you to search for files and their contents
    using powerful Unix tools wrapped in a user-friendly interface.

    Main Features:
    - Find files by type (file extension)
    - Search file contents using ripgrep-all (rga)
    - Preview files with syntax highlighting
    - Open files with various applications
    - Search within specific files

    Key Bindings in Search Results:
    - ESC: Exit current view
    - CTRL+/: Toggle preview window
    - CTRL+O: Open selected file in VS Code
    - CTRL+R: Open containing folder in Ranger

    Required Dependencies:
    - fd: Modern alternative to find
    - fzf: Fuzzy finder
    - rga (ripgrep-all): Search file contents
    - bat: Syntax highlighting for file preview
    - file: Identify file types

    Optional Dependencies:
    - timg: Terminal image viewer
    - pdftotext: Extract text from PDFs
    - ranger: File browser
    - code: VS Code editor
    HELP

    box = TTY::Box.frame(
      title: { top_left: ' Help ' },
      width: @width - 4,
      padding: 1
    ) do
      help_text
    end

    puts box
    @prompt.keypress('Press any key to continue...')
  end
end

# Start the application
if __FILE__ == $0
  app = FileExplorerCLI.new
  app.run
end
