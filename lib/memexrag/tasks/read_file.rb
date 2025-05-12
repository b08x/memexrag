# frozen_string_literal: true

module MemexRAG
  module Tasks
    class ReadFileTask < Jongleur::Worker
      sidekiq_options queue: 'file_ingestion', retry: 3

      def perform(file_path)
        puts "ReadFileTask: Reading file #{file_path}"
        begin
          file_content = File.read(file_path)
          # Simulate some processing time
          sleep(1)
          puts "ReadFileTask: Successfully read file #{file_path}"
          # Assuming ProcessContentTask is another Jongleur worker
          ProcessContentTask.perform_async(file_content, file_path)
        rescue StandardError => e
          puts "ReadFileTask: Error reading file #{file_path}: #{e.message}"
          # Consider retrying or pushing to a dead-letter queue
          raise e # Re-raise to trigger retry if sidekiq_options allows
        end
      end
    end
  end
end