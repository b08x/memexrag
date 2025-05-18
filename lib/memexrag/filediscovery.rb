# frozen_string_literal: true

module MemexRAG
  module FileDiscovery
    # Discovers files in the given source (file or directory) and groups them by type.
    #
    # @param source [String, Pathname] The file or directory to process
    # @return [Hash] A hash where keys are file types and values are arrays of file paths
    def self.discover(source)
      source_path = source.respond_to?(:realdirpath) ? source.realdirpath : Pathname.new(source).realdirpath

      raise ArgumentError, "Source does not exist: #{source}" unless source_path.exist?

      files = Hash.new { |h, k| h[k] = [] }

      if source_path.directory?
        discover_in_directory(source_path, files)
      elsif source_path.file?
        add_file_to_hash(source_path, files)
      else
        raise ArgumentError, "Source is neither a file nor directory: #{source}"
      end

      files
    end

    def self.discover_in_directory(directory, files)
      Dir.glob(File.join(directory, '**', '*')).each do |file|
        file_path = Pathname.new(file)
        next unless file_path.file?

        add_file_to_hash(file_path, files)
      end
    end

    def self.add_file_to_hash(file_path, files)
      extension = file_path.extname.downcase
      files[extension] << file_path.to_s
    end
  end
end
