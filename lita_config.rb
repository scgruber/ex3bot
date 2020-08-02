require 'json'
require_relative './adapter/discord'
require_relative './handler/ex3'

# This is a conflicting deprecation warning in redis-namespace, so suppress it in the output for now.
Redis.exists_returns_integer = false

Lita.configure do |config|
  discord_config = JSON.parse(File.read(ENV["DISCORD_CONFIG_FILE"]))

  # The name your robot will use.
  config.robot.name = discord_config["bot_name"]
  config.robot.mention_name = discord_config["bot_handle"]

  # The severity of messages to log. Options are:
  # :debug, :info, :warn, :error, :fatal
  # Messages at the selected level and above will be logged.
  config.robot.log_level = :info

  # The adapter you want to connect with. Make sure you've added the
  # appropriate gem to the Gemfile.
  config.robot.adapter = :discord
  config.adapters.discord.token = discord_config["bot_token"]

  ## Example: Set options for the Redis connection.
  config.redis = {
      host: "127.0.0.1",
      port: 6379,
  }
end
