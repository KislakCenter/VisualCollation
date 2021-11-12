# Adding Honeybadger configuration.

if Rails.env.production? && ENV['HONEYBADGER_API_KEY']
  Honeybadger.configure do |config|
    config.api_key = ENV['HONEYBADGER_API_KEY']
  end
end