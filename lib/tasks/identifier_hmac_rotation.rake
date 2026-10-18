# frozen_string_literal: true

require "pg"
require "uri"

namespace :identifier_hmac do
  desc "Rotate exactly one realm/channel through its restricted maintenance connection"
  task :rotate, %i(realm channel) => :environment do |_task, args|
    realm = args[:realm]
    channel = args[:channel]
    unless %w(app com org).include?(realm) && %w(email telephone).include?(channel)
      raise ArgumentError, "identifier rotation requires an explicit supported realm and channel"
    end

    database_url = ENV.fetch("IDENTIFIER_HMAC_MAINTENANCE_DATABASE_URL")
    begin
      location = URI.parse(database_url)
    rescue URI::InvalidURIError
      raise ArgumentError, "invalid identifier maintenance database URL", cause: nil
    end
    unless %w(postgres postgresql).include?(location.scheme) && location.user.present? &&
        location.host.present? && location.path.length > 1 && location.fragment.nil?
      raise ArgumentError, "identifier maintenance URL requires explicit user, host and database"
    end

    maintenance = PG.connect(database_url)
    begin
      operation = IdentifierHmacEmergencyRotation.new(
        realm: realm, channel: channel, maintenance_connection: maintenance,
      )
      function =
        case [realm, channel]
        when ["app", "email"] then "public.rotate_client_emails_hmac"
        when ["app", "telephone"] then "public.rotate_client_telephones_hmac"
        when ["com", "email"] then "public.rotate_visitor_emails_hmac"
        when ["com", "telephone"] then "public.rotate_visitor_telephones_hmac"
        when ["org", "email"] then "public.rotate_operator_emails_hmac"
        when ["org", "telephone"] then "public.rotate_operator_telephones_hmac"
        else raise ArgumentError, "unsupported identifier maintenance function"
        end
      definer = maintenance.exec_params(
        "SELECT r.rolname FROM pg_catalog.pg_proc p " \
        "JOIN pg_catalog.pg_roles r ON r.oid = p.proowner WHERE p.oid = $1::regprocedure",
        ["#{function}(bigint,text,text,uuid)"],
      ).getvalue(0, 0)
      prefix = "umaxica_#{realm}_#{channel}_hmac_definer_"
      unless definer.start_with?(prefix) && definer.delete_prefix(prefix).match?(/\A[0-9a-f]{12}\z/)
        raise ArgumentError, "identifier maintenance function has an invalid owner"
      end

      role = "umaxica_#{realm}_#{channel}_hmac_caller_#{definer.delete_prefix(prefix)}"
      maintenance.exec("SET ROLE #{PG::Connection.quote_ident(role)}")
      result = operation.call
      raise RuntimeError, "identifier rotation incomplete" unless result.records_failed.zero?

      puts "Identifier HMAC rotation completed for #{realm}/#{channel}."
    ensure
      maintenance.close
    end
  end
end
