namespace :db_connection do
  namespace :remote_server do
    task create: :environment do
      execute_sql "
        CREATE EXTENSION postgres_fdw;
        CREATE SERVER legacy FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '#{dbconfig[:host]}', dbname '#{dbconfig[:database]}', port '#{dbconfig[:port]}');
        CREATE USER MAPPING FOR CURRENT_USER SERVER legacy OPTIONS (user '#{dbconfig[:user]}', password '#{dbconfig[:password]}');
      "
    end

    task destroy: :environment do
      execute_sql "
        DROP SERVER legacy CASCADE;
        DROP EXTENSION postgres_fdw;
      "
    end
  end

  namespace :products_sequence do
    task create_products_id_seq_view: :environment do
      execute_sql "CREATE VIEW products_id_seq_view AS SELECT nextval('products_id_seq') as next_id;"
    end

    task drop_products_id_seq_view: :environment do
      execute_sql "DROP VIEW products_id_seq_view;"
    end
  end

  namespace :legacy_products_sequence do
    task create_foreign_products_id_sequence: :environment do
      execute_sql "
        CREATE FOREIGN TABLE foreign_products_id_seq (next_id bigint)
        server legacy
        OPTIONS (table_name 'products_id_seq_view');
      "
    end

    task drop_foreign_products_id_sequence: :environment do
      execute_sql "DROP FOREIGN TABLE foreign_products_id_seq;"
    end

    task create_or_update_foreign_products_id_sequence_function: :environment do
      execute_sql "
        CREATE OR REPLACE FUNCTION legacy_products_id_seq_nextval()
          RETURNS bigint AS
        $$
          SELECT next_id FROM foreign_products_id_seq;
        $$
        LANGUAGE 'sql';
      "
    end

    task drop_foreign_products_id_sequence_function: :environment do
      execute_sql "DROP FUNCTION legacy_products_id_seq_nextval();"
    end
  end

  namespace :legacy_products do
    task create_foreign_table: :environment do
      execute_sql "
        CREATE FOREIGN TABLE legacy_products (
            id          bigint,
            name        varchar(255),
            description varchar(255),
            price       integer,
            created_at  timestamp without time zone NOT NULL,
            updated_at  timestamp without time zone NOT NULL
          ) server legacy
        OPTIONS (table_name 'products');
      "
    end

    task drop_foreign_table: :environment do
      execute_sql "DROP FOREIGN TABLE legacy_products;"
    end
  end

  namespace :legacy_products do
    task create_insert_trigger: :environment do
      execute_sql "
        CREATE TRIGGER AfterProductsInsert
        AFTER INSERT
          ON products
          FOR EACH ROW
          EXECUTE PROCEDURE insert_legacy_products();
      "
    end

    task drop_insert_trigger: :environment do
      execute_sql "DROP TRIGGER AfterProductsInsert ON products;"
    end

    task create_or_update_insert_function: :environment do
      execute_sql "
        CREATE OR REPLACE FUNCTION insert_legacy_products()
          RETURNS trigger AS
        $$
        BEGIN
          INSERT INTO legacy_products(
            id,
            name,
            description,
            price,
            created_at,
            updated_at
          )
          values(
            NEW.id,
            NEW.name,
            NEW.description,
            NEW.price,
            clock_timestamp(),
            clock_timestamp()
          );
          PERFORM legacy_products_id_seq_nextval();
          RETURN NEW;
        EXCEPTION
          WHEN undefined_table THEN
            RETURN NEW;
        END;
        $$
        LANGUAGE 'plpgsql';
      "
    end

    task drop_insert_function: :environment do
      execute_sql "DROP FUNCTION insert_legacy_products();"
    end

    task create_update_trigger: :environment do
      execute_sql "
        CREATE TRIGGER AfterProductsUpdate
        AFTER UPDATE
          ON products
          FOR EACH ROW
          EXECUTE PROCEDURE update_legacy_products();
      "
    end

    task drop_update_trigger: :environment do
      execute_sql "DROP TRIGGER AfterProductsUpdate ON products;"
    end

    task create_or_update_update_function: :environment do
      execute_sql "
        CREATE OR REPLACE FUNCTION update_legacy_products()
          RETURNS trigger AS
        $$
        BEGIN
          UPDATE legacy_products SET
            name        = NEW.name,
            description = NEW.description,
            price       = NEW.price,
            updated_at  = NEW.updated_at
          WHERE id = NEW.id;
          RETURN NEW;
        EXCEPTION
          WHEN undefined_table THEN
            RETURN NEW;
        END;
        $$
        LANGUAGE 'plpgsql'
      "
    end

    task drop_update_function: :environment do
      execute_sql "DROP FUNCTION update_legacy_products();"
    end
  end

  task create: :environment do
    Rake::Task["db_connection:products_sequence:create_products_id_seq_view"].execute
    Rake::Task["db_connection:remote_server:create"].execute
    Rake::Task["db_connection:legacy_products_sequence:create_foreign_products_id_sequence"].execute
    Rake::Task["db_connection:legacy_products_sequence:create_or_update_foreign_products_id_sequence_function"].execute
    Rake::Task["db_connection:legacy_products:create_foreign_table"].execute
    Rake::Task["db_connection:legacy_products:create_or_update_insert_function"].execute
    Rake::Task["db_connection:legacy_products:create_or_update_update_function"].execute
    Rake::Task["db_connection:legacy_products:create_insert_trigger"].execute
    Rake::Task["db_connection:legacy_products:create_update_trigger"].execute
  end

  task destroy: :environment do
    Rake::Task["db_connection:legacy_products:drop_update_trigger"].execute
    Rake::Task["db_connection:legacy_products:drop_insert_trigger"].execute
    Rake::Task["db_connection:legacy_products:drop_update_function"].execute
    Rake::Task["db_connection:legacy_products:drop_insert_function"].execute
    Rake::Task["db_connection:legacy_products:drop_foreign_table"].execute
    Rake::Task["db_connection:legacy_products_sequence:drop_foreign_products_id_sequence"].execute
    Rake::Task["db_connection:legacy_products_sequence:drop_foreign_products_id_sequence_function"].execute
    Rake::Task["db_connection:remote_server:destroy"].execute
    Rake::Task["db_connection:products_sequence:drop_products_id_seq_view"].execute
  end

  private

  def execute_sql(sql)
    ActiveRecord::Base.connection.execute(sql)
  end

  def dbconfig
    {
      host: ENV["LEGACY_DATABASE_HOST"],
      port: ENV["LEGACY_DATABASE_PORT"],
      database: ENV["LEGACY_DATABASE"],
      user: ENV["LEGACY_DATABASE_USER"],
      password: ENV["LEGACY_DATABASE_PASSWORD"],
    }
  end
end
