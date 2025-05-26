# frozen_string_literal: true

class Audio < Sequel::Model(PGConnect.instance.db[:audio_files])
  plugin :validation_helpers
  plugin :insert_conflict
  def validate
    super
    validates_presence :title
    validates_unique :title
  end
end
