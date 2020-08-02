require 'lita'
require 'discordrb'

module Lita::Adapters
  class Discord < Lita::Adapter
    config :token, type: String, required: true

    def initialize(robot)
      super
      @client = Discordrb::Bot.new(token: config.token)
    end

    def run
      @client.message do |event|
        user = Lita::User.find_by_id(event.author.id) || Lita::User.create(event.author.id, name: event.author.username)
        room = Lita::Room.create_or_update(event.channel.id, name: event.channel.name)
        source = Lita::Source.new(user: user, room: room)
        message = Lita::Message.new(robot, event.content, source)
        log.debug("Received \"#{message.body}\" from @#{message.source.user.name} in ##{message.source.room_object.name}")
        robot.receive(message)
      end

      @client.run
    end

    def shut_down
      @client.stop
    end

    def send_messages(target, messages)
      channel = target.room || @client.user(target.user.id).dm
      messages.each do |message|
        @client.send_message(channel, message)
      end
    end

    def set_topic(target, topic)
      raise StandardError.new("Unimplemented")
    end

    # Discord users do not join channels specifically
    def join(room_id)
      raise StandardError.new("Unimplemented")
    end

    # Discord users do not leave channels specifically
    def part(room_id)
      raise StandardError.new("Unimplemented")
    end
  end

  Lita.register_adapter(:discord, Discord)
end
