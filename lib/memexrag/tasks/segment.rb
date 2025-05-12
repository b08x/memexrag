#!/usr/bin/env ruby
# frozen_string_literal: true

# This task segments the text content of a Document into smaller units.
class SegmentText < Jongleur::WorkerTask
  # Performs the task logic to segment the text content.
  DEFAULT_OPTIONS = { language: 'en', doc_type: 'none', clean: false }
  # The text to be segmented.
  attr_accessor :text

  # The options for the segmenter.
  attr_accessor :options

  def initialize
    @text = text
    @options = DEFAULT_OPTIONS.merge(opts)
    logger.debug "TextSegmenter initialized with options: #{@options}"

    logger.info "Starting text segmentation"
    logger.debug "Input text type: #{@text.class}"

    if @text.instance_of?(Array)
      segment_array
    else
      segment_string(@text)
    end
  end

  # @return [Document] The processed Document with segments added
  def execute
    logger.info "Starting TextSegment for file: #{@sourcefile.name}"

    ps = PragmaticSegmenter::Segmenter.new(text: txt, **@options)
    ps.segment

    segments = text_segmenter.process(@sourcefile.content, { clean: true })

    store_segments(@sourcefile, segments)

    logger.info 'TextSegment completed'
    @sourcefile
  end

  private


  # Segments an array of text.
  #
  # @return [Array] An array of segments.
  def segment_array
    logger.debug "Segmenting array of strings"
    @text.flat_map do |txt|
      segment_string(txt)
    end
  end
end
