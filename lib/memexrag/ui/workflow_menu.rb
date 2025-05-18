#!/usr/bin/env ruby
# frozen_string_literal: true

# https://claude.site/artifacts/ade3eb91-4ec1-4e89-ad15-6482651b2081

class WorkflowMenu
  def initialize
    @prompt = TTY::Prompt.new(
      active_color: :bright_cyan,
      help_color: :bright_white,
      prefix: "\n#{Pastel.new.bright_cyan('⚡')} "
    )
  end

  def display
    loop do
      case main_menu_choice
      when :import then handle_import_workflow
      when :process then handle_processing_workflow
      when :analyze then handle_analysis_workflow
      when :status then display_system_status
      when :quit then break
      end
    end
  end

  private

  def main_menu_choice
    @prompt.select("What would you like to do?", per_page: 5) do |menu|
      menu.choice "📥 Import Media", :import
      menu.choice "⚙️ Process Content", :process
      menu.choice "🔍 Analyze Content", :analyze
      menu.choice "📊 System Status", :status
      menu.choice "👋 Exit", :quit
    end
  end

  def handle_import_workflow
    case @prompt.select("Import Options:", per_page: 4) do |menu|
      menu.choice "Import Single File", :single
      menu.choice "Import Directory", :directory
      menu.choice "Import from URL", :url
      menu.choice "Back", :back
    end
    when :single
      path = @prompt.ask("Enter file path:") do |q|
        q.validate(%r{^/.*$}, "Must be absolute path")
      end
      Import.new(path).start if path
    when :directory
      path = @prompt.ask("Enter directory path:") do |q|
        q.validate(%r{^/.*$}, "Must be absolute path")
      end
      Import.new(path).start if path
    when :url
      url = @prompt.ask("Enter URL:") do |q|
        q.validate(%r{^https?://.*$}, "Must be valid URL")
      end
      # Implement URL import logic
    end
  end

  def handle_processing_workflow
    choices = @prompt.multi_select(
      "Select content to process:",
      per_page: 10,
      echo: false
    ) do |menu|
      Collection.all.each do |collection|
        menu.choice "#{collection.name} (#{collection.file_objects.count} files)", collection.id
      end
    end

    return if choices.empty?

    workflow = @prompt.select("Choose workflow:") do |menu|
      menu.choice "Text Pre-Processing Pipeline", :text_pre_processing
      menu.choice "Text Processing Pipeline", :text_processing
      menu.choice "Media Transcription", :transcription
      menu.choice "Topic Model Training", :topic_model
      menu.choice "Custom Workflow", :custom
    end

    process_selected_content(choices, workflow)
  end

  def handle_analysis_workflow
    collection = @prompt.select("Select collection to analyze:") do |menu|
      Collection.all.each do |c|
        menu.choice "#{c.name} (#{c.file_objects.count} files)", c
      end
    end

    return unless collection

    case @prompt.select("Choose analysis type:") do |menu|
      menu.choice "Topic Analysis", :topics
      menu.choice "Content Statistics", :stats
      menu.choice "Entity Recognition", :entities
      menu.choice "Custom Analysis", :custom
    end
    when :topics
      analyze_topics(collection)
    when :stats
      display_content_stats(collection)
    when :entities
      analyze_entities(collection)
    when :custom
      design_custom_analysis
    end
  end

  def display_system_status
    stats = collect_system_stats

    table = TTY::Table.new(
      header: %w[Metric Value],
      rows: [
        ["Collections", stats[:collections]],
        ["Total Files", stats[:total_files]],
        ["Processed Files", stats[:processed_files]],
        ["Storage Used", stats[:storage_used]],
        ["Redis Keys", stats[:redis_keys]],
        ["Active Workers", stats[:active_workers]]
      ]
    )

    puts "\nSystem Status"
    puts table.render(:unicode, padding: [0, 1]) { |renderer|
      renderer.border.separator = :each_row
    }

    press_any_key
  end

  private

  def process_selected_content(collection_ids, workflow_type)
    spinner = TTY::Spinner.new(
      "[:spinner] Processing #{collection_ids.count} collections ...",
      format: :dots
    )
    spinner.auto_spin

    begin
      # Initialize appropriate workflow
      workflow_class = case workflow_type
                       when :text_pre_processing then TextPreProcessingWorkflow
                       when :text_processing then TextProcessingWorkflow
                       when :transcription then TranscriptionWorkflow
                       when :topic_model then TopicModelTrainerWorkflow
                       when :custom then CustomWorkflow
                       end

      workflow = workflow_class.new
      workflow.run

      spinner.success("(Processing complete!)")
    rescue StandardError => e
      spinner.error("(#{e.message})")
    end
  end

  def collect_system_stats
    {
      collections: Collection.all.count,
      total_files: FileObject.all.count,
      processed_files: FileObject.all.count { |f| f.processed },
      storage_used: format_bytes(calculate_storage_used),
      redis_keys: Ohm.redis.call("DBSIZE"),
      active_workers: count_active_workers
    }
  end

  def calculate_storage_used
    # Implementation for calculating total storage used
    FileObject.all.sum do |f|
      File.size(f.path)
    rescue StandardError
      0
    end
  end

  def count_active_workers
    # Implementation for counting active worker processes
    `pgrep -f "workflow_worker" | wc -l`.strip.to_i
  end

  def format_bytes(bytes)
    units = %w[B KB MB GB TB]
    return "0B" if bytes == 0

    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = units.length - 1 if exp > units.length - 1
    format("%.1f %s", bytes.to_f / (1024**exp), units[exp])
  end

  def press_any_key
    @prompt.keypress("\nPress any key to continue...")
  end
end
