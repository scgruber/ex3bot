require_relative '../model/character'

module Lita::Handlers
  class Ex3 < Lita::Handler
    ### Chat Handlers
    route(/^join\s+(?:([^\s\"]+)|\"([^\"]+)\")\s+(-?\d+)$/, :join, command: true, help: {
        "join CHARACTER NUM" => "Add CHARACTER to the initiative order with NUM initiative."
    })
    route(/^init\s+(?:([^\s\"]+)|\"([^\"]+)\")\s+(-?\d+)$/, :init, command: true, help: {
        "init CHARACTER NUM" => "Set initiative for CHARACTER to NUM."
    })
    route(/^act\s+(?:([^\s\"]+)|\"([^\"]+)\")$/, :act, command: true, help: {
        "act CHARACTER" => "Mark CHARACTER as acted for the current round."
    })
    route(/^round$/, :round, command: true, help: {
        "round" => "Advance to the next round, resetting the active state."
    })
    route(/^show$/, :show, command: true, help: {
        "show" => "Display all characters in initiative order, separating acted and pending characters for the current round."
    })
    route(/^finish$/, :finish, command: true, help: {
        "finish" => "End the combat and remove all characters from the initiative order."
    })

    def join(response)
      log.debug("Triggering #join")
      name = response.match_data.captures[0] || response.match_data.captures[1]
      room = response.message.source.room
      initiative = response.match_data.captures[2].to_i

      character = Ex3Bot::Character.create!(redis, room, name)
      character.initiative!(initiative)
      robot.trigger(:list_order, room: response.message.source.room_object)
    end

    def init(response)
      log.debug("Triggering #init")
      name = response.match_data.captures[0] || response.match_data.captures[1]
      room = response.message.source.room
      initiative = response.match_data.captures[2].to_i

      character = Ex3Bot::Character.new(redis, room, name)
      if character.exists?
        character.initiative!(initiative)
        robot.trigger(:list_order, room: response.message.source.room_object)
      else
        robot.trigger(:error_no_name, room: response.message.source.room_object, name: name)
      end
    end

    def act(response)
      log.debug("Triggering #act")
      name = response.match_data.captures[0] || response.match_data.captures[1]
      room = response.message.source.room

      character = Ex3Bot::Character.new(redis, room, name)
      if character.exists?
        character.acted!(true)
        robot.trigger(:list_order, room: response.message.source.room_object)
      else
        robot.trigger(:error_no_name, room: response.message.source.room_object, name: name)
      end
    end

    def round(response)
      log.debug("Triggering #round")
      room = response.message.source.room_object
      characters = Ex3Bot::Character.all_in_room(redis, room.id)
      characters.each do |c|
        c.acted!(false)
      end

      response.reply("Next round! Recover 5 motes.")
      robot.trigger(:list_order, room: room)
    end

    def show(response)
      log.debug("Triggering #act")
      robot.trigger(:list_order, room: response.message.source.room_object)
    end

    def finish(response)
      log.debug("Triggering #finish")
      room = response.message.source.room_object
      characters = Ex3Bot::Character.all_in_room(redis, room.id)
      characters.each do |c|
        c.delete!
      end
      response.reply("Combat has ended.")
    end

    ### Event handlers
    on :list_order, :list_order
    on :error_no_name, :error_no_name

    # Print the current initiative list in order.
    # Splits up characters that have not acted / have acted in this round.
    def list_order(room:)
      log.debug("Triggering #list_order")
      message = ""
      characters = Ex3Bot::Character.all_in_room(redis, room.id)
      if characters.empty?
        robot.send_message(Lita::Source.new(room: room), "There are no characters in combat.")
      else
        grouped_characters = characters.group_by { |c| c.acted ? :acted : :pending }.transform_values { |cs| cs.sort_by { |c| -c.initiative } }
        grouped_characters[:pending] ||= []
        grouped_characters[:acted] ||= []

        message << "Not acted this round:\n"
        grouped_characters[:pending].each do |c|
          message << c.to_s + "\n"
        end

        message << "\nActed this round:\n"
        grouped_characters[:acted].each do |c|
          message << c.to_s + "\n"
        end

        robot.send_message(Lita::Source.new(room: room), message)
      end
    end

    # Posts an error message that the character name is not found.
    def error_no_name(room:, name:)
      log.debug("Triggering #error_no_name")
      robot.send_message(Lita::Source.new(room: room), "Name not found: #{name}")
    end
  end

  Lita.register_handler(Ex3)
end
