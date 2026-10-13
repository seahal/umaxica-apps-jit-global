# typed: false
# frozen_string_literal: true

# Inclusion-time callbacks are retained because every PublicId record must mint
# and validate the identifier on create; an explicit per-model hook would
# duplicate the same persistence contract on every including class.
module PublicId
  extend ActiveSupport::Concern

  GENERATION_SIZE = 21
  STORAGE_SIZE = 25
  MAX_COLLISION_RETRIES = 3

  class << self
    public

    def generate
      Nanoid.generate(size: GENERATION_SIZE, non_secure: false)
    end
  end

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    before_create :generate_public_id
    before_validation :generate_public_id, on: :create
    before_validation :refresh_generated_public_id_after_collision, on: :create
    around_create :retry_public_id_collision
    validate :public_id_immutable_after_create, on: :update

    validates :public_id, presence: true, length: { maximum: STORAGE_SIZE }, uniqueness: true
  end

  public

  def to_param
    public_id
  end

  private

  def generate_public_id
    return if public_id.present?

    self.public_id = PublicId.generate
    @public_id_generated_value = public_id
  end

  def retry_public_id_collision
    return yield unless @public_id_generated_value == public_id

    public_id_constraints = public_id_unique_constraint_names
    return yield if public_id_constraints.empty?

    retries = 0

    begin
      self.class.transaction(requires_new: true) { yield }
    rescue ActiveRecord::RecordNotUnique => e
      raise unless public_id_constraints.include?(postgres_constraint_name(e))

      retries += 1
      raise if retries > MAX_COLLISION_RETRIES

      self.public_id = nil
      generate_public_id
      retry
    end
  end

  def refresh_generated_public_id_after_collision
    return unless @public_id_generated_value == public_id
    return unless self.class.exists?(public_id: public_id)

    self.public_id = nil
    generate_public_id
  end

  def public_id_immutable_after_create
    return unless persisted? && will_save_change_to_public_id?

    errors.add(:public_id, "cannot be changed after creation")
  end
  private :public_id_immutable_after_create

  def public_id_unique_constraint_names
    self.class.lease_connection.schema_cache.indexes(self.class.table_name).filter_map do |index|
      index.name if index.unique && index.where.nil? && index.columns == ["public_id"]
    end
  end

  def postgres_constraint_name(error)
    result = error.cause&.result
    return unless result

    result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
  end
end
