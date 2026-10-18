# frozen_string_literal: true

# Assigns a missing owned public identity during an explicitly authorized transition.
#
# The supported models are deliberately enumerated. This operation is not a generic repair path
# and must never be called from a normal create, read or update request.
class PublicIdNullOnlyBackfillOperation
  TARGETS = [
    [ClientPreference, "index_client_preferences_on_public_id"],
    [VisitorPreference, "index_visitor_preferences_on_public_id"],
    [OperatorPreference, "index_operator_preferences_on_public_id"],
    [ClientPasskey, "index_client_passkeys_on_public_id"],
  ].freeze

  class << self
    public

    def call(scope:, dry_run:, batch_size:)
      model, index_name = target_for(scope)
      unless [true, false].include?(dry_run) && batch_size.is_a?(Integer) && (1..1000).cover?(batch_size)
        raise ArgumentError, "public identity backfill requires an explicit mode and bounded batch size"
      end

      assigned = 0
      model.connection_class_for_self.connected_to(role: :writing) do
        unless dry_run
          scope.where(public_id: nil).in_batches(of: batch_size) do |batch|
            batch.each { |record| assigned += 1 if assign_identity!(record, index_name:) }
          end
        end
        { assigned: assigned, missing: scope.where(public_id: nil).count }.freeze
      end
    end

    private

    def target_for(scope)
      unless scope.is_a?(ActiveRecord::Relation)
        raise ArgumentError, "public identity backfill requires an explicit supported scope"
      end

      target = TARGETS.find { |model, _index_name| scope.klass == model }
      raise ArgumentError, "public identity backfill scope is unsupported" unless target

      target
    end

    def assign_identity!(record, index_name:)
      record.with_lock do
        next false unless record.public_id.nil?

        retries = 0
        begin
          identity = PublicId.generate
          record.class.transaction(requires_new: true) do
            # Explicit NULL-only maintenance under a row lock; ordinary identity updates remain
            # forbidden. Avoid unrelated callbacks/timestamps and preserve all source facts.
            # rubocop:disable Rails/SkipsModelValidations
            unless record.update_columns(public_id: identity)
              raise ActiveRecord::StaleObjectError.new(record, "public identity backfill")
            end
            # rubocop:enable Rails/SkipsModelValidations
          end
        rescue ActiveRecord::RecordNotUnique => e
          constraint = e.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
          raise unless constraint == index_name

          retries += 1
          raise if retries > PublicId::MAX_COLLISION_RETRIES

          retry
        end
        true
      end
    end
  end
end
