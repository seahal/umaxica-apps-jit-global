# frozen_string_literal: true

class OperatorTelephonePublicIdBackfillOperation
  class << self
    public

    def call(scope:, dry_run:, batch_size:)
      unless scope.is_a?(ActiveRecord::Relation) && scope.klass == OperatorTelephone &&
          [true, false].include?(dry_run) && batch_size.is_a?(Integer) && (1..1000).cover?(batch_size)
        raise ArgumentError, "ORG Telephone backfill requires an explicit scope, mode and bounded batch size"
      end

      assigned = 0
      OperatorTelephone.connection_class_for_self.connected_to(role: :writing) do
        unless dry_run
          scope.where(public_id: nil).in_batches(of: batch_size) do |batch|
            batch.each { |telephone| assigned += 1 if assign_identity!(telephone) }
          end
        end
        { assigned: assigned, missing: scope.where(public_id: nil).count }.freeze
      end
    end

    private

    def assign_identity!(telephone)
      telephone.with_lock do
        next false unless telephone.public_id.nil?

        retries = 0
        begin
          identity = PublicId.generate
          OperatorTelephone.transaction(requires_new: true) do
            # Explicit NULL-only maintenance under a row lock; ordinary identity updates remain
            # forbidden. Avoid unrelated callbacks/timestamps and preserve issued proof facts.
            # rubocop:disable Rails/SkipsModelValidations
            unless telephone.update_columns(public_id: identity)
              raise ActiveRecord::StaleObjectError.new(telephone, "public identity backfill")
            end
            # rubocop:enable Rails/SkipsModelValidations
          end
        rescue ActiveRecord::RecordNotUnique => e
          constraint = e.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
          raise unless constraint == "index_operator_telephones_on_public_id"

          retries += 1
          raise if retries > PublicId::MAX_COLLISION_RETRIES

          retry
        end
        true
      end
    end
  end
end
