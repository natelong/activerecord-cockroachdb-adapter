require "cases/helper_cockroachdb"
require "cases/helper"
require "support/ddl_helper"
require "support/connection_helper"

module CockroachDB
  module ConnectionAdapters
    class PostgreSQLAdapterTest < ActiveRecord::PostgreSQLTestCase
      self.use_transactional_tests = false
      include DdlHelper
      include ConnectionHelper

      def setup
        @connection = ActiveRecord::Base.connection
        @connection_handler = ActiveRecord::Base.connection_handler
      end

      def teardown
        # use connection without follower_reads and telemetry
        database_config = { "adapter" => "cockroachdb", "database" => "activerecord_unittest" }
        ar_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        database_config.update(ar_config.configuration_hash)

        ActiveRecord::Base.establish_connection(database_config)
      end

      def test_database_exists_returns_false_when_the_database_does_not_exist
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        config = db_config.configuration_hash.dup
        config[:database] = "non_extant_database"
        assert_not ActiveRecord::ConnectionAdapters::CockroachDBAdapter.database_exists?(config),
                   "expected database #{config[:database]} to not exist"
      end

      def test_database_exists_returns_true_when_the_database_exists
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        assert ActiveRecord::ConnectionAdapters::CockroachDBAdapter.database_exists?(db_config.configuration_hash),
          "expected database #{db_config.database} to exist"
      end

      def test_using_telemetry_builtin_connects_properly
        database_config = { "adapter" => "cockroachdb", "database" => "activerecord_unittest" }
        ar_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        database_config.update(ar_config.configuration_hash)
        database_config[:disable_cockroachdb_telemetry] = false

        ActiveRecord::Base.establish_connection(database_config)
        conn = ActiveRecord::Base.connection
        conn_config = conn.instance_variable_get("@config")

        assert_equal(false, conn_config[:disable_cockroachdb_telemetry])
      end

      def test_using_follower_reads_connects_properly
        database_config = { "use_follower_reads_for_type_introspection": true, "adapter" => "cockroachdb", "database" => "activerecord_unittest" }
        ar_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        database_config.update(ar_config.configuration_hash)

        ActiveRecord::Base.establish_connection(database_config)
        conn = ActiveRecord::Base.connection
        conn_config = conn.instance_variable_get("@config")

        assert conn_config[:use_follower_reads_for_type_introspection]
      end

      def test_only_reload_type_map_once_for_every_unrecognized_type
        reset_connection
        connection = ActiveRecord::Base.connection

        silence_stream($stdout) do
          assert_queries 2, ignore_none: true do
            connection.select_all "select 'pg_catalog.pg_class'::regclass"
          end
          assert_queries 1, ignore_none: true do
            connection.select_all "select 'pg_catalog.pg_class'::regclass"
          end
          assert_queries 2, ignore_none: true do
            connection.select_all "SELECT NULL::anyarray"
          end
        end
      ensure
        reset_connection
      end
    end
  end
end
