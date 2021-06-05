namespace :db_connection do
  namespace :remote_server do
    task create: :environment do
      execute_sql "
        CREATE EXTENSION postgres_fdw;
        CREATE SERVER new FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '#{dbconfig[:host]}', dbname '#{dbconfig[:database]}', port '#{dbconfig[:port]}');
        CREATE USER MAPPING FOR CURRENT_USER SERVER new OPTIONS (user '#{dbconfig[:user]}', password '#{dbconfig[:password]}');
      "
    end

    task destroy: :environment do
      execute_sql "
        DROP SERVER new CASCADE;
        DROP EXTENSION postgres_fdw;
      "
    end
  end

  namespace :new_products do
    task create_foreign_table: :environment do
      execute_sql "
        CREATE FOREIGN TABLE new_products (
            id          bigint,
            name        varchar(255),
            description varchar(255),
            price       integer,
            created_at  timestamp without time zone NOT NULL,
            updated_at  timestamp without time zone NOT NULL
          ) server new
        OPTIONS (table_name 'products');
      "
    end

    task drop_foreign_table: :environment do
      execute_sql "DROP FOREIGN TABLE new_products;"
    end

    task create_insert_trigger: :environment do
      execute_sql "
        CREATE TRIGGER AfterProductsInsert
        AFTER INSERT
          ON products
          FOR EACH ROW
          EXECUTE PROCEDURE insert_new_products();
      "
    end

    task drop_insert_trigger: :environment do
      execute_sql "DROP TRIGGER AfterProductsInsert ON products;"
    end

    task create_or_update_insert_function: :environment do
      execute_sql "
        CREATE OR REPLACE FUNCTION insert_new_products()
          RETURNS trigger AS
        $$
        BEGIN
          INSERT INTO new_products(
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
      execute_sql "DROP FUNCTION insert_new_products();"
    end

    task create_update_trigger: :environment do
      execute_sql "
        CREATE TRIGGER AfterProductsUpdate
        AFTER INSERT
          ON products
          FOR EACH ROW
          EXECUTE PROCEDURE insert_new_products();
      "
    end

    task drop_update_trigger: :environment do
      execute_sql "DROP TRIGGER AfterProductsUpdate ON products;"
    end

    task create_or_update_update_function: :environment do
      execute_sql "
        CREATE OR REPLACE FUNCTION update_new_products()
          RETURNS trigger AS
        $$
        BEGIN
          UPDATE new_products SET
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
      execute_sql "DROP FUNCTION update_new_products();"
    end
  end

  task create: :environment do
    Rake::Task["db_connection:remote_server:create"].execute
    Rake::Task["db_connection:new_products:create_foreign_table"].execute
    Rake::Task["db_connection:new_products:create_or_update_insert_function"].execute
    Rake::Task["db_connection:new_products:create_or_update_update_function"].execute
    Rake::Task["db_connection:new_products:create_insert_trigger"].execute
    Rake::Task["db_connection:new_products:create_update_trigger"].execute
  end

  task destroy: :environment do
    Rake::Task["db_connection:new_products:drop_update_trigger"].execute
    Rake::Task["db_connection:new_products:drop_insert_trigger"].execute
    Rake::Task["db_connection:new_products:drop_update_function"].execute
    Rake::Task["db_connection:new_products:drop_insert_function"].execute
    Rake::Task["db_connection:new_products:drop_foreign_table"].execute
    Rake::Task["db_connection:remote_server:destroy"].execute
  end

  private

  def execute_sql(sql)
    ActiveRecord::Base.connection.execute(sql)
  end

  def dbconfig
    {
      host: ENV["NEW_DATABASE_HOST"],
      port: ENV["NEW_DATABASE_PORT"],
      database: ENV["NEW_DATABASE"],
      user: ENV["NEW_DATABASE_USER"],
      password: ENV["NEW_DATABASE_PASSWORD"],
    }
  end
end
