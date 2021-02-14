# db_sync

In new_app:
docker-compose up --build
docker-compose run --rm app bundle exec rake db:create db:migrate #TODO db:seed

In legacy_app
docker-compose up --build
docker-compose run --rm app bundle exec rake db:create db:migrate #TODO db:seed

In new_app:
docker-compose run --rm app bundle exec rake db_connection:remote_server:create
docker-compose run --rm app bundle exec rake db_connection:legacy_products:create_foreign_table

docker-compose run --rm app bundle exec rails db

#TODO:
\l and look for remote database
\d and look for legacy_products table
select * from legacy_products;
