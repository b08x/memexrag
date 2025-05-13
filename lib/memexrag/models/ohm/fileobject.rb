#!/usr/bin/env ruby
# frozen_string_literal: true

# Base FileObject model
class FileObject < Ohm::Model
  class FileObjectError < StandardError; end

  include Ohm::Timestamps
  include Ohm::DataTypes
  include Ohm::Callbacks

  # File type definitions
  FILE_TYPES = {
    text: ['.txt', '.md', '.markdown'],
    pdf: ['.pdf'],
    html: ['.html', '.htm'],
    json: ['.json', '.jsonl'],
    audio: ['.mp3', '.wav', '.ogg', '.flac', '.opus', '.m4a'],
    video: ['.mp4', '.avi', '.mov', '.mkv']
  }.freeze

  attribute :name
  attribute :path
  attribute :extension
  attribute :type
  attribute :processed, Type::Time

  unique :path

  index :name
  index :path
  index :extension
  index :type

  # Factory method to create appropriate file object based on type
  def self.create_for_file(file_path, collection = nil)
    raise ArgumentError, 'file_path must be a String' unless file_path.is_a?(String)
    raise FileObjectError, "File not found: #{file_path}" unless File.exist?(file_path)

    # Check if file already exists in database
    existing = find(path: file_path).first
    raise Ohm::UniqueIndexViolation, 'what the fuck?' if existing

    #    return existing if existing

    file_name = File.basename(file_path)
    extension = File.extname(file_path).downcase
    type = determine_file_type(extension)

    # Create specific file object based on type
    klass = case type
            when :text then TextFile
            when :audio then AudioFile
            when :video then VideoFile
            else FileObject
            end

    # Create base file object
    file_object = create(
      name: file_name,
      path: file_path,
      extension: extension,
      type: type.to_s,
      collection: collection
    )

    # Create specialized object if needed
    if klass != FileObject
      klass.create(file_object: file_object, collection: file_object.collection)
      # file_object.update(processed: Time.now)
    end
    file_object
  end

  def self.determine_file_type(extension)
    FILE_TYPES.each do |type, extensions|
      return type if extensions.include?(extension.downcase)
    end
    :unknown
  end

  def self.latest
    fetch(redis.call('ZRANGE', key[:latest], 0, -1))
  end

  protected

  def after_save
    redis.call('ZADD', model.key[:latest], Time.now.to_i, id)
  end

  def after_delete
    redis.call('ZREM', model.key[:latest], id)
  end
end
