# frozen_string_literal: true

class RpStepUpDispatchRecoveryJob < ApplicationJob
  queue_as :retention

  public

  def perform
    RpStepUpDispatchRecovery.call(cell: RpStepUpCellRegistry.fetch(RpCellBinding.fetch("rp_base_app")).cell)
    RpStepUpDispatchRecovery.call(cell: RpStepUpCellRegistry.fetch(RpCellBinding.fetch("rp_base_org")).cell)
  end
end
