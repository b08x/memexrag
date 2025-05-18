# frozen_string_literal: true
class SublayerTaskGenerator < Sublayer::Generators::Base
  llm_output_adapter type: :named_strings,
    name: "sublayer_task",
    description: "The new sublayer task based on the description and supporting information",
    attributes: [
      { name: "code", description: "The code of the generated Sublayer task" },
      { name: "filename", description: "The filename of the generated sublayer task snake cased with a .rb extension" }
    ]

  def initialize(description:)
    @description = description
  end

  def generate
    super
  end

  def prompt
    <<-PROMPT
    You are an expert ruby programmer and are great at repurposing code examples to use for new situations.

    A Sublayer Task is an example of a command pattern that is used in the Sublayer AI framework to perform tasks in the outside world such as orchestrating complex processes or aggregating data.

    The Sublayer framework also has a component called a Generator that takes data in, sends it to an LLM and gets structured data out.
    Sublayer::Tasks are used both to retrieve data for use in a generator or perform tasks based on the output of the generator.
    This is used to both aid in generating new composable bits of functionality and to ease testing.

    A sublayer task is initialized with the data it needs and then exposes a `call` method which is used to perform the task.

    An example of a task being used to orchestrate a multi-step workflow is:
    <example_workflow_task>
    #{example_workflow_task}
    </example_workflow_task>

    Another example of a task might be aggregating data from multiple sources:
    <example_data_aggregation_task>
    #{example_data_aggregation_task}
    </example_data_aggregation_task>

    Your task is to generate a new Sublayer::Task::Base subclass that performs a task based on the description provided.
    <description>
    #{@description}
    </description>
    PROMPT
  end

  private
  def example_workflow_task
    # Provide the implementation for reading a workflow task example
    File.read(File.join(File.dirname(__FILE__), 'example_task_workflow.rb'))
  end

  def example_data_aggregation_task
    # Provide the implementation for reading a data aggregation task example
    File.read(File.join(File.dirname(__FILE__), 'example_task_data_aggregation.rb'))
  end
end