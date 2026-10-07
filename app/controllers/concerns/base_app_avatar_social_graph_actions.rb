# typed: false
# frozen_string_literal: true

module BaseAppAvatarSocialGraphActions
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    before_action :authenticate_client!
  end

  private

  def actor_avatar
    @actor_avatar ||= Avatar.find_by!(public_id: Actor.selection.avatar_public_id)
  end

  def target_avatar
    @target_avatar ||= Avatar.find_by!(public_id: params.fetch(:avatar_id))
  end

  def render_edge(edge)
    render json: { public_id: edge.id.to_s }, status: :created
  end
end
