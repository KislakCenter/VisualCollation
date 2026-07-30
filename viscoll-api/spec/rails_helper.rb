# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'

ENV['RAILS_ENV'] = 'test'
require File.expand_path('../../config/environment', __FILE__)

module TestDatabaseSafety
  EXPECTED_DATABASE_NAME = 'viscoll_test'.freeze

  def self.client
    raise "RSpec must run in the test environment" unless Rails.env.test?

    client = Mongoid.default_client
    database_name = client.database.name
    return client if database_name == EXPECTED_DATABASE_NAME

    raise "RSpec must use #{EXPECTED_DATABASE_NAME}, not #{database_name}"
  end

  def self.clean!
    client.collections.each do |collection|
      next if collection.name.start_with?('system.')

      collection.find.delete_many
    end
  end
end

TestDatabaseSafety.client

require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!
require 'mongoid-rspec'
require 'rails_jwt_auth/spec/helpers'

# Rails.application.eager_load!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# configure shoulda matchers to use rspec as the test framework and full matcher libraries for rails
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # add `FactoryGirl` methods
  config.include FactoryGirl::Syntax::Methods

  # add 'Mongoid' matchers
  config.include Mongoid::Matchers, type: :model

  # add 'WardenHelper'
  config.include RailsJwtAuth::Spec::Helpers, :type => :request

  # Start each suite with an empty test database.
  config.before(:suite) do
    TestDatabaseSafety.clean!
  end

  # MongoDB transactions are not available with the current standalone server,
  # so clear the verified test database after every example.
  config.around(:each) do |example|
    begin
      example.run
    ensure
      TestDatabaseSafety.clean!
    end
  end
end
