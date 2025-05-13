# frozen_string_literal: true

# generate a MemexRAG::Commands class that lists and retrives prompts, takes using the LangfuseClient::Client object on intialize,
# use the same design as the FileExplorerCLI

module MemexRAG
  module Commands
    class Prompts < BaseCommand
      def self.command_name
        'prompts'
      end

      def self.description
        'List and retrieve prompts.'
      end

      def initialize(options)
        super
        @langfuse_client = LangfuseClient::Client.new
      end

      def execute(subcommand, *args)
        case subcommand
        when 'list'
          list_prompts
        when 'get'
          get_prompt(args[0]) # Assuming the first arg is the prompt version
        else
          puts 'Invalid subcommand. Available subcommands: list, get'
        end
      end

      private

      def list_prompts
        # Assuming Langfuse client can fetch all prompts
        prompts = @langfuse_client.list_prompts # Replace with actual method if different
        if prompts.nil? || prompts.empty?
          puts 'No prompts found.'
          return
        end

        puts 'Available Prompts:'
        prompts.each do |prompt|
          p prompt
        end
        prompts.each do |prompt|
          puts "- ID: #{prompt.version}, Name: #{prompt.name}" # Adjust keys based on actual data structure
        end
      rescue StandardError => e
        puts "Error listing prompts: #{e.message}"
      end

      def get_prompt(prompt_name)
        # Assuming Langfuse client can fetch a specific prompt by ID
        prompt = @langfuse_client.get_prompt(prompt_name) # Replace with actual method if different
        if prompt.nil?
          puts "Prompt with name '#{prompt_name}' not found."
          return
        end

        puts 'Prompt Details:'
        puts "ID: #{prompt[:version]}"
        puts "Name: #{prompt[:name]}"
        puts "Content: #{prompt[:prompt_content]}" # Adjust keys based on actual data structure
      rescue StandardError => e
        puts "Error getting prompt: #{e.message}"
      end
    end
  end
end
