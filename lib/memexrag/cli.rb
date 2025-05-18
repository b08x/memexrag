# frozen_string_literal: true

module MemexRAG
  class CLI < Thor
    class_option :model,
                 type: :string,
                 aliases: '-m',
                 banner: 'MODEL_NAME',
                 description: 'Global: Specify LLM model for any command that uses one.'
    class_option :langfuse_prompt_name,
                 type: :string,
                 aliases: '-p',
                 banner: 'PROMPT_NAME',
                 description: 'Global: Name of Langfuse system prompt (if applicable to command/session).'
    class_option :langfuse_prompt_version,
                 type: :numeric,
                 aliases: '-pv',
                 banner: 'VERSION',
                 description: 'Global: Version of Langfuse system prompt.'
    class_option :langfuse_prompt_label,
                 type: :string,
                 aliases: '-pl',
                 banner: 'LABEL',
                 description: 'Global: Label of Langfuse system prompt.'

    MemexRAG::Commands.constants.reject{ |command_class| command_class == :BaseCommand }.each do |command_class|
      command = MemexRAG::Commands.const_get(command_class)
      desc command.command_name, command.description
      define_method(command.command_name) do |*args|
        command.new(options).execute(*args)
      end
    end
  end
end
