# frozen_string_literal: true

# File: lib/spacy_model_registry.rb
# https://g.co/gemini/share/7b3250e7e121
# (Ensure ruby-spacy is available, e.g., require 'spacy-ruby')
# If Spacy module is not globally available, adjust the require path.

require 'ruby-spacy'
require 'mutex_m'

# The SpacyModelRegistry provides a centralized way to load and cache
# spaCy language models, ensuring that each model is loaded only once.
# This is akin to a singleton factory for spaCy language instances.
module SpacyModelRegistry
  extend Mutex_m # Make this module thread-safe for concurrent access

  @loaded_models = {}

  # Retrieves a spaCy language model by its name.
  # If the model is already loaded, it returns the cached instance.
  # Otherwise, it loads the model, caches it, and then returns it.
  # This method is thread-safe.
  #
  # @param model_name [String] The name of the spaCy model to load (e.g., 'en_core_web_trf').
  # @return [Spacy::Language] The loaded spaCy language model.
  # @raise [StandardError] If the model fails to load.
  def self.get_model(model_name)
    # Use self.synchronize for thread-safety provided by Mutex_m
    synchronize do
      return @loaded_models[model_name] if @loaded_models.key?(model_name)

      puts "[SpacyModelRegistry] Loading spaCy model: #{model_name}..."
      begin
        model = Spacy::Language.new(model_name)
        @loaded_models[model_name] = model
        puts "[SpacyModelRegistry] Successfully loaded and cached spaCy model: #{model_name}."
        model
      rescue PyCall::PyError, StandardError => e
        # Log the error prominently. Depending on application needs,
        # this could raise a custom error, or return a NullObject pattern.
        # For now, re-raise to make failure explicit.
        warn "[SpacyModelRegistry] CRITICAL: Failed to load spaCy model '#{model_name}'. Details: #{e.message}"
        raise "SpacyModelRegistry: Failed to load model #{model_name}. Original error: #{e.class} - #{e.message}"
      end
    end
  end

  # Optional: A method to clear the cache, primarily for testing or specific reload scenarios.
  def self.clear_cache!
    synchronize do
      @loaded_models.each_value do |model|
        # If spaCy models have a specific close/cleanup method, call it here.
        # For now, we're just clearing the Ruby references. Python GC will handle the rest.
      end
      @loaded_models = {}
      puts '[SpacyModelRegistry] Cache cleared.'
    end
  end
end
