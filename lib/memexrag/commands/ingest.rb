# frozen_string_literal: true

VALID_FILE_TYPES = FileObject::FILE_TYPES.values.flatten.map { |ext| ext.delete_prefix('.') }.join(',')

module MemexRAG
  module Commands
    class Ingest < BaseCommand
      attr_accessor :files

      def self.description
        'Ingest an incident file to create or update a Memex trail'
      end

      # The 'file_path' will be passed by Thor from the CLI
      def execute(*args)
        # --- This is where the magic happens ---
        files = []

        args.each do |arg|
          source = Pathname.new(arg)
          if source.realdirpath.directory?
            files += Dir.glob(File.join(source.realdirpath, "**{,/*/**}/*.{#{VALID_FILE_TYPES}}"))
          elsif source.realdirpath.file?
            files << source.realdirpath
          else
            puts 'neither file nor directory, exiting'
            sleep 1
            next
          end
        rescue StandardError => e
          logger.debug("#{e.message}")
        end

        files = files.map { |file| Pathname.new(file) }
        import = MemexRAG::Workflow::Import.new(files)
        import.run
        # Step A: Validate file_path
        # Step B: Read file content
        # Step C: Process content (extract text, metadata)
        # Step D: Store in PostgreSQL (raw content, metadata)
        # Step E: Generate vector embeddings
        # Step F: Store embeddings in Redis (for POC)
        # Step G: Create initial graph entry in RedisGraph (basic node)
        # Step H: (Future) Integrate with Langfuse for tracing the ingestion
        # Step I: Provide feedback to the user (success/failure)
      end
    end
  end
end