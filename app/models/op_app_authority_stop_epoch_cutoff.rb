# typed: false
# frozen_string_literal: true

class OpAppAuthorityStopEpochCutoff < OpBaseAppRecord
  belongs_to :stop, class_name: "OpAppAuthorityStop", inverse_of: :epoch_cutoff

  validates :cutoff_epoch, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
end
