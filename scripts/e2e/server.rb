# frozen_string_literal: true

STDOUT.sync = true
STDERR.sync = true

require "socket"
require "ipaddr"
require "fileutils"

abort "Rails browser E2E requires RAILS_ENV=test and RACK_ENV=test" unless
  ENV.fetch("RAILS_ENV") == "test" && ENV.fetch("RACK_ENV") == "test"
abort "Use the dedicated Playwright configuration" unless ENV.fetch("RAILS_BROWSER_E2E") == "1"

# Reserve before any preparation. Never adopt an existing listener, including a 404/500 server.
loopback = IPAddr.new(Socket::INADDR_LOOPBACK, Socket::AF_INET).to_s
listener = TCPServer.new(loopback, 3198)
listener.close_on_exec = true

require_relative "../../config/boot"
abort "E2E Valkey must use loopback, localhost, or the local valkey-kvs service" unless
  [loopback, "localhost", "valkey-kvs"].include?(ENV.fetch("VALKEY_KVS_HOST"))
abort "E2E requires config/credentials/test.key; unset the generic RAILS_MASTER_KEY override" if ENV["RAILS_MASTER_KEY"]
require_relative "http_guard"
require_relative "../../config/application"
expected_credentials = Rails.root.join("config/credentials/test.yml.enc")
expected_key = Rails.root.join("config/credentials/test.key")
abort "E2E requires the dedicated test credentials and test.key files" unless
  expected_credentials.file? && expected_key.file? &&
    Rails.application.config.credentials.content_path.realpath == expected_credentials.realpath &&
    Rails.application.config.credentials.key_path.realpath == expected_key.realpath
require_relative "../../test/support/valkey_test_isolation"
require "puma"

databases_verified = false
server = nil
stopping = false
%w(INT TERM).each do |signal|
  Signal.trap(signal) do
    stopping = true
    server.nil? ? Thread.main.raise(Interrupt) : server.stop
  end
end

begin
  # Share ordinary test databases with Minitest; concurrent runs are refused.
  FileUtils.mkdir_p(Rails.root.join("tmp"))
  database_lock = Rails.root.join("tmp/parallel-test-databases.lock").open(File::RDWR | File::CREAT, 0o600)
  abort("Test databases are in use by another test process") unless database_lock.flock(File::LOCK_EX | File::LOCK_NB)

  Rails.application.initialize!
  Umaxica::TestEnvironment::DatabaseSafety.verify_catalog!
  configurations = ActiveRecord::Base.configurations.configs_for(env_name: "test", include_hidden: true)
  test_databases = configurations.map(&:database)
  databases_verified = true
  pools = ActiveRecord::Base.connection_handler.connection_pool_list(:all)
  pools.each do |pool|
    abort("E2E connection pool escaped configured test databases") unless
      test_databases.include?(pool.db_config.database)
    pool.with_connection do |connection|
      abort("E2E live database identity differs from its pool") unless
        connection.select_value("SELECT current_database()") == pool.db_config.database
    end
  end
  puts "Rails E2E: verified #{pools.length} live connection pools target configured test databases"
  abort("E2E CSRF protection is required") unless ActionController::Base.allow_forgery_protection
  abort("E2E requires test mail, SMS and job adapters") unless
    Rails.configuration.action_mailer.delivery_method == :test && Rails.configuration.sms_provider == "test" &&
      Rails.configuration.active_job.queue_adapter == :test

  # Test Flipper is process-local memory: explicitly prepare the real availability switch.
  # This configures only Auth public availability, without bypassing its gate.
  availability_adapter = Flipper::Adapters::Memory.new
  Flipper.configure { |configuration| configuration.adapter { availability_adapter } }
  Flipper.new(availability_adapter).enable(FqdnAvailabilityRegistry.flag_name_for(:auth_service))

  valkey = Umaxica::Valkey::Settings.current
  [valkey.rate_limit, valkey.auth_state].each do |setting|
    connection = Umaxica::Valkey::Connection.new(url: setting.url, namespace: "e2e_preflight")
    begin
      abort("Valkey did not answer PONG") unless connection.call("PING") == "PONG"
    rescue Umaxica::Valkey::Unavailable
      warn("Rails E2E: Valkey KVS test DB #{setting.db} unavailable; start valkey-kvs and check VALKEY_KVS_HOST/PORT")
      raise
    ensure
      connection.close
    end
  end
  puts "Rails E2E: Valkey test DBs 4/6 reachable; scope #{ENV.fetch("VALKEY_NAMESPACE_RUN_ID")}:browser"
  abort("Vite test build failed; inspect the build output") unless ViteRuby.commands.build
  raise Interrupt if stopping

  Rails.application.load_server
  server = Puma::Server.new(Rails.application)
  server.binder.inherit_tcp_listener(loopback, 3198, listener)
  puts "Rails E2E: Puma starting on auth.app.localhost:3198 (test, CSRF enabled)"
  server_thread = server.run
  puts "Rails E2E: ready"
  server_thread.join
rescue Interrupt
  warn("Rails E2E: interrupted")
ensure
  server&.stop(true)
  listener.close unless listener.closed?
  if databases_verified
    begin
      ValkeyTestIsolation.cleanup_worker_keys!
    ensure
      ActiveRecord::Base.connection_handler.clear_all_connections!
    end
    puts "Rails E2E: Valkey scope cleaned; database connections closed; Puma stopped"
  end
end
