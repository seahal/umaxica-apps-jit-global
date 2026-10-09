# frozen_string_literal: true

require "minitest/autorun"

# Guards .agents/harnesses/rules/project/value-object-boundaries.mdc.
#
# `app/services` had become a support root rather than a layer: 236 files carrying 115 distinct
# name suffixes, of which only 9 ended in `service`. Nothing distinguished a service from anything
# else filed beside it, because only 46 of those files inherit ApplicationService and the root is
# flat, so neither the type nor the path carried the role.
#
# This test pins the half of the placement rule that is mechanically checkable: a suffix owned by
# another root must not appear under `app/services`. It reads the filesystem rather than loading
# Rails, so it runs without a database or the compose environment.
#
# PENDING lists the files still awaiting their migration issue. Shrinking it is the point: each
# migration issue deletes its entries, which turns this test red until the files actually move.
# Do not add entries to make the suite green - see project/regression-guards.mdc.
class ObjectPlacementTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)

  # A suffix and the single root that owns it. Only unambiguous suffixes belong here; roles such as
  # `Issuer`, which names both a persisting operation and a pure token minter, are decided per file
  # in research/2026-08-29-object-placement-inventory.md rather than by name.
  OWNED_SUFFIXES = {
    "consumer" => "app/consumers",
    "query" => "app/queries",
    "resolver" => "app/resolvers",
    "serializer" => "app/serializers",
    "validator" => "app/validators",
  }.freeze

  # Files that still sit in the wrong root, each with the issue that moves it. Entries are removed
  # by that issue, not to quiet a failure.
  PENDING = {}.freeze

  # Concerns live under a concerns root, which is already the classifier, so the suffix rule does
  # not reach them. See value-object-boundaries.mdc, "Exceptions to the suffix rule".
  CONCERN_ROOTS = %r{(\A|/)concerns/}

  def test_no_file_carries_a_suffix_owned_by_another_root
    offenders =
      ruby_files_under("app").reject { |path| PENDING.key?(path) || path.match?(CONCERN_ROOTS) }.filter_map do |path|
        suffix = File.basename(path, ".rb").split("_").last
        owner = OWNED_SUFFIXES[suffix]
        next if owner.nil?
        next if path.start_with?("#{owner}/")

        "#{path} carries the `#{suffix}` suffix, which belongs to #{owner}"
      end

    assert_empty offenders,
                 "Filed under a root that does not own the role suffix " \
                 "(see value-object-boundaries.mdc):\n#{offenders.join("\n")}"
  end

  # Suffixes that name a state change. A Service orchestrates; an object that performs one write
  # is not a service, and app/services held 50 of them.
  WRITE_SIDE_SUFFIXES = %w(
    issuer committer purger revoker recorder writer finalizer creator provisioner anonymizer
    invalidator
  ).freeze

  # Token minters keep the Issuer name and live in app/lib: they build and sign a payload and
  # persist nothing, so the suffix describes the domain act rather than a state change. Decided in
  # research/2026-08-29-object-placement-inventory.md after reading each Issuer individually.
  TOKEN_MINTERS = %w(
    app/lib/jump_rt_issuer.rb
    app/lib/oidc_id_token_issuer.rb
    app/lib/identity_step_up_ceremony_result_issuer.rb
  ).freeze

  def test_write_side_objects_are_not_in_app_services
    offenders =
      ruby_files_under("app/services").select do |path|
        WRITE_SIDE_SUFFIXES.include?(File.basename(path, ".rb").split("_").last)
      end

    assert_empty offenders,
                 "app/services holds objects that perform a state change " \
                 "(see value-object-boundaries.mdc):\n#{offenders.join("\n")}"
  end

  def test_token_minters_stay_out_of_the_write_side_root
    misplaced = TOKEN_MINTERS.reject { |path| File.exist?(File.join(REPOSITORY_ROOT, path)) }

    assert_empty misplaced,
                 "Token minters build and sign a payload and persist nothing, so they belong in " \
                 "app/lib:\n#{misplaced.join("\n")}"
  end

  # app/validators is the one root Rails itself gives a meaning: ActiveModel wires its contents
  # into `validates`. A protocol or request check filed here is not that, and would never be
  # invoked by the framework.
  def test_validators_are_active_model_validators
    offenders =
      ruby_files_under("app/validators").reject do |path|
        File.read(File.join(REPOSITORY_ROOT, path)).match?(/<\s*ActiveModel::(Each)?Validator\b/)
      end

    assert_empty offenders,
                 "app/validators holds files that are not ActiveModel validators " \
                 "(see value-object-boundaries.mdc):\n#{offenders.join("\n")}"
  end

  # Roots whose contents must end in one of the root's allowed suffixes, so that a file names its
  # own role the way xxx_controller.rb does. Only roots that are fully compliant are listed; the
  # remainder are added as their migration issue makes them so.
  #
  # Not yet listed, with the reason:
  #   app/services   - #868 has not run; the root is still mixed
  #   app/policies   - three files need a rule decision (sign_up_step_gate, quota_limits,
  #                    step_up_available_methods)
  #   app/adapters   - MCP tools and provider/cache names need a rule decision
  #   app/lib        - ports and primitives, suffix set not settled
  #   app/values     - 96 files grandfathered until #870
  ROOT_SUFFIXES = {
    "app/consumers" => %w(consumer),
    "app/forms" => %w(form),
    "app/notifiers" => %w(notifier),
    "app/operations" => %w(
      operation command issuer committer purger revoker recorder writer finalizer creator
      provisioner anonymizer invalidator guard authority enforcer
    ),
    "app/presenters" => %w(presenter),
    "app/queries" => %w(query inventory locator),
    "app/resolvers" => %w(resolver),
    "app/serializers" => %w(serializer),
    "app/subscribers" => %w(subscriber),
    "app/validators" => %w(validator),
  }.freeze

  # An error namespace holds Error classes rather than being one, so it cannot carry the suffix
  # without the constant lying about what it is.
  SUFFIX_EXEMPT = ["app/errors/identity_telephone_ceremony.rb"].freeze

  def test_every_file_names_its_own_role
    offenders =
      ROOT_SUFFIXES.flat_map do |root, suffixes|
        ruby_files_under(root).reject { |path| SUFFIX_EXEMPT.include?(path) }.filter_map do |path|
          suffix = File.basename(path, ".rb").split("_").last
          next if suffixes.include?(suffix)

          "#{path} does not end in #{suffixes.join(", ")}"
        end
      end

    assert_empty offenders,
                 "Files in a role root do not name their role " \
                 "(see value-object-boundaries.mdc):\n#{offenders.join("\n")}"
  end

  # Roots a model must not depend on. A Service orchestrates models and an Operation performs a
  # write on their behalf, so either arrow pointing back at a model inverts the layering.
  FORBIDDEN_MODEL_DEPENDENCY_ROOTS = %w(app/services app/operations).freeze

  # Constants in those roots that app/models still reaches for, each with the issue that resolves
  # it.
  MODEL_DEPENDENCIES_PENDING = {
    # Chronicle.capture writes Chronicle rows through these operations. The model here is the audit
    # table itself, so this is a model persisting its own records through extracted steps, not a
    # service orchestrating it - see
    # research/2026-08-29-chronicle-and-enforcement-write-dependencies.md. #869 also found that
    # Chronicle.capture has no production caller, which is the question to settle first.
    "ChronicleIntentWriter" => 869,
    "ChronicleResultWriter" => 869,
    "ChronicleInvalidator" => 869,
    "ChronicleFallbackRecorder" => 869,
    # EnforcementAppeal#resolve! ends the Case it belongs to. Same fat-model shape #871 removed one
    # level up, and it calls the end operation inside its own transaction rather than outside it.
    "EnforcementCaseEndOperation" => 872,
  }.freeze

  def test_models_do_not_depend_on_the_write_side
    defined_in_forbidden_roots =
      FORBIDDEN_MODEL_DEPENDENCY_ROOTS.flat_map { |root| ruby_files_under(root).map { |path| [root, path] } }
        .to_set do |root, path|
        path.delete_prefix("#{root}/").delete_suffix(".rb").split(%r{[/_]}).map(&:capitalize).join
      end

    referenced =
      ruby_files_under("app/models").flat_map do |path|
        File.read(File.join(REPOSITORY_ROOT, path))
          .gsub(/#.*/, "")
          .scan(/\b[A-Z][A-Za-z0-9]+\b/)
      end.to_set

    offenders =
      (defined_in_forbidden_roots & referenced)
        .reject { |constant| MODEL_DEPENDENCIES_PENDING.key?(constant) }
        .sort

    assert_empty offenders,
                 "app/models depends on constants defined under app/services or app/operations " \
                 "(see value-object-boundaries.mdc, Dependency direction):\n#{offenders.join("\n")}"
  end

  def test_pending_entries_still_exist
    missing = PENDING.keys.reject { |path| File.exist?(File.join(REPOSITORY_ROOT, path)) }

    assert_empty missing,
                 "PENDING names files that no longer exist, so this guard no longer checks " \
                 "them:\n#{missing.join("\n")}"
  end

  # Several security guards pin a boundary by reading a source file at a hardcoded path. A move
  # that leaves one behind raises Errno::ENOENT from inside an unrelated test, which is a slow and
  # confusing way to find out - it is how #868 discovered it had broken
  # identity_authority_inversion_guard_test. Only paths that are actually read are checked;
  # allowlists naming a path that must not exist are a different thing and are left alone.
  def test_no_hardcoded_path_points_at_a_missing_file
    sources = Dir.glob(File.join(REPOSITORY_ROOT, "{test,config,lib}/**/*.rb"))
    offenders =
      sources.flat_map do |source|
        relative = source.delete_prefix("#{REPOSITORY_ROOT}/")
        next [] if relative == "test/tooling/object_placement_test.rb"

        File.read(source).lines.grep(/Rails\.root\.join|file_content\(/).flat_map do |line|
          line.scan(%r{\bapp/[a-z_]+/[a-z_0-9/]+\.rb\b}).filter_map do |path|
            "#{relative} reads #{path}, which does not exist" unless File.exist?(File.join(REPOSITORY_ROOT, path))
          end
        end
      end

    assert_empty offenders,
                 "A hardcoded source path no longer resolves:\n#{offenders.join("\n")}"
  end

  private

  def ruby_files_under(directory)
    Dir.glob(File.join(REPOSITORY_ROOT, directory, "**", "*.rb")).map do |path|
      path.delete_prefix("#{REPOSITORY_ROOT}/")
    end.sort
  end
end
