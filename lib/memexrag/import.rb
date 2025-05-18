#!/usr/bin/env ruby
# frozen_string_literal: true

require 'parallel'
class Import
  attr_reader :collection, :source, :files

  def initialize(source)
    @source = source.respond_to?(:realdirpath) ? source : Pathname.new(source)
    raise ArgumentError, "Source does not exist: #{source}" unless @source.exist?

    collection_name = UI.prompt.ask('Collection name?')
    @collection = Collection.find_or_create(collection_name)
    @files = MemexRAG::FileDiscovery.discover(@source)
  end

  def start
    total_files = @files.values.flatten.count

    Parallel.map(
      @files.values.flatten,
      progress: "Adding #{total_files} Files to Database",
      in_processes: 1
    ) do |file_path|
      file_object = FileObject.new(file_path)
      @collection.add_item(
        path: file_object.path.cleanpath.to_s,
        name: file_object.name,
        type: file_object.type.to_s,
        mime: file_object.mime_type,
        extension: file_object.extension,
        size: file_object.size
      )
      UI.say(:ok, "Added #{file_object}")
    rescue Sequel::UniqueConstraintViolation => e
      logger.warn "<'#{file_path}'> already exists in database\n#{e.message}"
    rescue StandardError => e
      logger.error "Error processing #{file_path}: #{e.message}"
    end
  end

  private

  def display_import_statistics
    table = TTY::Table.new(
      header: %w[Metric Value],
      rows: generate_stat_rows
    )

    puts "\nImport Statistics for Collection: #{@collection.name}"
    puts table.render(:unicode, padding: [0, 1], alignment: %i[left right]) { |renderer|
      renderer.border.separator = :each_row
      renderer.filter = lambda { |val, row_index, col_index|
        if col_index == 1 && row_index > 0 # Apply color to values only
          case row_index
          when 1..5  # File type counts
            Pastel.new.cyan(val)
          when 6     # Total size
            Pastel.new.yellow(val)
          when 7     # Successful imports
            Pastel.new.green(val)
          when 8     # Duplicates
            Pastel.new.blue(val)
          when 9     # Errors
            Pastel.new.red(val)
          else
            val
          end
        else
          val
        end
      }
    }
  end

  def generate_stat_rows
    rows = []

    # Header section for file types
    rows << ['File Types', 'Count']

    # File type statistics
    %i[text audio video pdf unknown].each do |type|
      next if @import_stats[type].zero?

      rows << [type.to_s.capitalize, @import_stats[type].to_s]
    end

    # General statistics
    rows << ['Total Size', format_size(@import_stats[:total_size])]
    rows << ['Successfully Imported', @import_stats[:success].to_s]
    rows << ['Duplicates Skipped', @import_stats[:duplicates].to_s]
    rows << ['Errors Encountered', @import_stats[:errors].to_s]

    # Processing status
    processed = @collection.file_objects.count { |fo| fo.processed }
    total = @collection.file_objects.count
    rows << ['Processing Status', "#{processed}/#{total} files"]

    rows
  end

  def format_size(bytes)
    units = %w[B KB MB GB TB]
    return '0B' if bytes == 0

    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = units.length - 1 if exp > units.length - 1
    format('%.1f %s', bytes.to_f / (1024**exp), units[exp])
  end
end
