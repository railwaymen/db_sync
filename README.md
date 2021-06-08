# db_sync

### Setup

To run example applications, install docekr, clone the repository and do the following steps:

In /new_app path:
- docker-compose up --build
- docker-compose run --rm app bundle exec rake db:create db:migrate
- docker-compose run --rm app bundle exec rake db_connection:create

new_app will be accessible on localhost:3000

In /legacy_app path:
- docker-compose up --build
- docker-compose run --rm app bundle exec rake db:create db:migrate
- docker-compose run --rm app bundle exec rake db_connection:create

legacy_app will be accessible on localhost:3001

To remove connection:
- docker-compose run --rm app bundle exec rake db_connection:destroy 
