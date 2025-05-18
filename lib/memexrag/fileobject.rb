#!/usr/bin/env ruby
# frozen_string_literal: true

# The FileObject class handles gathering and validating file attributes, and determining
# file types. It serves as a foundational class that provides clean file metadata to
# the Ohm models (TextFile, AudioFile, VideoFile).
#
# Example:
#   begin
#     file = FileObject.new("/path/to/file.txt")
#     if file.processable?
#       # Create appropriate Ohm model with file.attributes
#     end
#   rescue FileObject::Error => e
#     # Handle error
#   end
class FileObject
  # Custom error class for FileObject-specific errors
  class Error < StandardError; end

  # Supported file types and their extensions
  FILE_TYPES = {
    text: %w[.txt .md .markdown .org],
    pdf: %w[.pdf],
    html: %w[.html .htm],
    json: %w[.json .jsonl],
    audio: %w[.mp3 .wav .ogg .flac .opus .m4a .aiff],
    video: %w[.mp4 .avi .mov .mkv .webm]
  }.freeze

  # File attributes
  attr_reader :name, :path, :extension, :type, :size, :mime_type

  # Initializes a new FileObject instance
  #
  # @param file_path [String, Pathname] Path to the file
  # @raise [FileObject::Error] If file_path is invalid or file doesn't exist
  def initialize(file_path)
    @path = validate_and_normalize_path(file_path)

    gather_basic_attributes
    gather_file_stats
    determine_mime_type
  rescue StandardError => e
    raise Error, "Failed to initialize FileObject: #{e.message}"
  end

  # Determines if file is processable by the system
  #
  # @return [Boolean] True if file type is supported
  def processable?
    FILE_TYPES.key?(@type)
  end

  # Returns hash of file attributes for Ohm model creation
  #
  # @return [Hash] File attributes
  def attributes
    {
      name: @name,
      path: @path.to_s,
      extension: @extension,
      type: @type,
      size: @size,
      mime_type: @mime_type
    }
  end

  # Returns a string representation of the FileObject
  #
  # @return [String] String representation
  def to_s
    "#{@name} (#{@type})"
  end

  # Returns a detailed inspection of the FileObject
  #
  # @return [String] Detailed string representation
  def inspect
    "#<FileObject name=#{@name} type=#{@type} size=#{format_size(@size)}>"
  end

  private

  def validate_and_normalize_path(file_path)
    path = convert_to_pathname(file_path)
    validate_file_existence(path)
    path.realpath
  end

  def convert_to_pathname(file_path)
    case file_path
    when String
      Pathname.new(file_path)
    when Pathname
      file_path
    else
      raise Error, "File path must be a String or Pathname, got: #{file_path.class}"
    end
  end

  def validate_file_existence(path)
    raise Error, "File not found: #{path}" unless path.exist?
    raise Error, "Not a file: #{path}" unless path.file?
    raise Error, "File not readable: #{path}" unless path.readable?
  end

  def gather_basic_attributes
    @name = @path.basename.to_s
    @extension = @path.extname.downcase
    @type = determine_file_type
  end

  def determine_file_type
    FILE_TYPES.find { |_type, extensions| extensions.include?(@extension) }&.first || :unknown
  end

  def gather_file_stats
    stat = @path.stat
    @size = stat.size
  rescue StandardError => e
    logger.error("Error gathering file stats for #{@path}: #{e.message}")
    raise Error, "Failed to gather file stats: #{e.message}"
  end

  def determine_mime_type
    @mime_type = MimeMagic.by_path(@path.to_s)&.type || 'application/octet-stream'
  rescue StandardError => e
    logger.warn("Error determining MIME type for #{@path}: #{e.message}")
    @mime_type = 'application/octet-stream'
  end

  def format_size(bytes)
    units = %w[B KB MB GB TB]
    return '0B' if bytes.zero?

    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = units.length - 1 if exp > units.length - 1
    format('%.1f %s', bytes.to_f / (1024**exp), units[exp])
  end
end
