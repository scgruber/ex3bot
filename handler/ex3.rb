require_relative '../model/character'

module Lita::Handlers
  class Ex3 < Lita::Handler
    ### Chat Handlers
    route(/^join\s+(?:(?<name>[^\s\"]+)|\"(?<name_quoted>[^\"]+)\")\s+(?<num>-?\d+)$/, :join, command: true, help: {
        "join CHARACTER NUM" => "Add CHARACTER to the initiative order with NUM initiative."
    })
    route(/^init\s+(?:(?<name>[^\s\"]+)|\"(?<name_quoted>[^\"]+)\")\s+(?<num>-?\d+)$/, :init, command: true, help: {
        "init CHARACTER NUM" => "Set initiative for CHARACTER to NUM."
    })
    route(/^loc\s+(?:(?<name>[^\s\"]+)|\"(?<name_quoted>[^\"]+)\")\s+(?:(?<place>[^\s\"]+)|\"(?<place_quoted>[^\"]*)\")$/, :loc, commmand: true, help: {
        "loc CHARACTER PLACE" => "Set location for CHARACTER to PLACE."
    })
    route(/^anima\s+(?:(?<name>[^\s\"]+)|\"(?<name_quoted>[^\"]+)\")\s+(?<level>[a-z]+)$/, :anima, command: true, help: {
        "anima CHARACTER LEVEL" => "Set anima level for CHARACTER to LEVEL."
    })
    route(/^ons\s+(?:(?<name>[^\s\"]+)|\"(?<name_quoted>[^\"]+)\")\s+(?<num>-?\d+)$/, :ons, command: true, help: {
        "ons CHARACTER NUM" => "Set onslaught for CHARACTER to NUM."
    })
    route(/^wither\s+(?:(?<attacker>[^\s\"]+)|\"(?<attacker_quoted>[^\"]+)\")\s+(?<attacker_imod>[+-]\d+)\s+>\s+(?:(?<defender>[^\s\"]+)|\"(?<defender_quoted>[^\"]+)\")\s+(?<defender_imod>[+-]\d+)$/, :wither, command: true, help: {
        "wither ATTACKER AMOD > DEFENDER DMOD" => "Withering attack. ATTACKER initiative changes by AMOD. DEFENDER initiative changes by DMOD. Defender gains onslaught."
    })
    route(/^wound\s+(?:(?<name>[^\s\"]+)|\"(?<name_quoted>[^\"]+)\")\s+(?<num>-?\d+)$/, :wound, command: true, help: {
        "wound CHARACTER NUM" => "Set wound penalty for CHARACTER to NUM."
    })
    route(/^decisive\s+(?:(?<attacker>[^\s\"]+)|\"(?<attacker_quoted>[^\"]+)\")\s+(?<attacker_ireset>-?\d+)\s+>\s+(?:(?<defender>[^\s\"]+)|\"(?<defender_quoted>[^\"]+)\")\s+(?<defender_wound>-?\d+)$/, :decisive, command: true, help: {
        "wither ATTACKER IRESET > DEFENDER WOUND" => "Withering attack. ATTACKER initiative resets to IRESET. DEFENDER wound penalty changes to WOUND. Defender gains onslaught."
    })
    route(/^act\s+(?:(?<name>[^\s\"]+)|\"(?<name_quoted>[^\"]+)\")$/, :act, command: true, help: {
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

    # Create a new character in the current room.
    # Set the character's initiative to <num>.
    # Display the initiative order.
    def join(response)
      log.debug("Triggering #join")
      name, room = get_name_and_room(response)
      initiative = response.match_data.named_captures["num"].to_i

      character = Ex3Bot::Character.create!(redis, room.id, name)
      character.initiative = initiative
      robot.trigger(:list_order, room: room)
    end

    # Set a character's initiative to <num>.
    # Display the initiative order.
    def init(response)
      log.debug("Triggering #init")
      name, room = get_name_and_room(response)
      initiative = response.match_data.named_captures["num"].to_i

      with_character(robot, redis, room, name) do |character|
        character.initiative = initiative
        robot.trigger(:list_order, room: room)
      end
    end

    # Set a character's location to <place>.
    # Display the initiative order.
    def loc(response)
      log.debug("Triggering #loc")
      name, room = get_name_and_room(response)
      location = response.match_data.named_captures["place"] || response.match_data.named_captures["place_quoted"]

      with_character(robot, redis, room, name) do |character|
        character.location = location
        robot.trigger(:list_order, room: room)
      end
    end

    # Set a character's anima level to <level>.
    # Display the initiative order.
    def anima(response)
      allowed = ["dim", "glowing", "burning", "bonfire"]

      log.debug("Triggering #anima")
      name, room = get_name_and_room(response)
      anima = response.match_data.named_captures["level"]
      unless allowed.include?(anima)
        response.reply("Anima level must be one of: #{allowed.join(', ')}")
        return
      end

      with_character(robot, redis, room, name) do |character|
        character.anima = anima
        robot.trigger(:list_order, room: room)
      end
    end

    # Set a character's onslaught to <num>.
    # If onslaught is > 0, send an error message instead.
    # Display the initiative order.
    def ons(response)
      log.debug("Triggering #ons")
      name, room = get_name_and_room(response)
      onslaught = response.match_data.named_captures["num"].to_i
      if onslaught > 0
        response.reply("Onslaught modifier must be 0 or negative.")
        return
      end

      with_character(robot, redis, room, name) do |character|
        character.onslaught = onslaught
        robot.trigger(:list_order, room: room)
      end
    end

    # Modify attacker initiative by <attacker_imod>.
    # Modify defender initiative by <defender_imod>.
    # Worsen defender onslaught penalty by 1.
    def wither(response)
      log.debug("Triggering #wither")
      attacker_name = response.match_data.named_captures["attacker"] || response.match_data.named_captures["attacker_quoted"]
      attacker_imod = response.match_data.named_captures["attacker_imod"]
      defender_name = response.match_data.named_captures["defender"] || response.match_data.named_captures["defender_quoted"]
      defender_imod = response.match_data.named_captures["defender_imod"]
      room = response.message.source.room_object

      with_character(robot, redis, room, attacker_name) do |attacker|
        with_character(robot, redis, room, defender_name) do |defender|
          attacker.initiative += attacker_imod.to_i
          defender.initiative += defender_imod.to_i
          defender.onslaught -= 1
          robot.trigger(:list_order, room: room)
        end
      end
    end

    # Set a character's wound penalty to <num>.
    # If wound penalty is > 0, send an error message instead.
    # Display the initiative order.
    def wound(response)
      log.debug("Triggering #wound")
      name, room = get_name_and_room(response)
      wound_penalty = response.match_data.named_captures["num"].to_i
      if wound_penalty > 0
        response.reply("Wound penalty must be 0 or negative.")
        return
      end

      with_character(robot, redis, room, name) do |character|
        character.wound = wound_penalty
        robot.trigger(:list_order, room: room)
      end
    end

    # Reset attacker initiative to <attacker_ireset>.
    # Set defender wound penalty to <defender_wound>.
    # Worsen defender onslaught penalty by 1.
    def decisive(response)
      log.debug("Triggering #decisive")
      attacker_name = response.match_data.named_captures["attacker"] || response.match_data.named_captures["attacker_quoted"]
      attacker_ireset = response.match_data.named_captures["attacker_ireset"]
      defender_name = response.match_data.named_captures["defender"] || response.match_data.named_captures["defender_quoted"]
      defender_wound = response.match_data.named_captures["defender_wound"]
      room = response.message.source.room_object

      with_character(robot, redis, room, attacker_name) do |attacker|
        with_character(robot, redis, room, defender_name) do |defender|
          attacker.initiative = attacker_ireset.to_i
          defender.wound = defender_wound.to_i
          defender.onslaught -= 1
          robot.trigger(:list_order, room: room)
        end
      end
    end

    # Set a character to the acted state.
    # Reset onslaught to 0.
    # Display the initiative order.
    def act(response)
      log.debug("Triggering #act")
      name, room = get_name_and_room(response)

      with_character(robot, redis, room, name) do |character|
        character.acted = true
        character.onslaught = 0
        robot.trigger(:list_order, room: room)
      end
    end

    # Set all characters out of the acted state.
    # Post a message to start the next round.
    # Display the initiative order.
    def round(response)
      log.debug("Triggering #round")
      room = response.message.source.room_object
      characters = Ex3Bot::Character.all_in_room(redis, room.id)
      characters.each do |c|
        c.acted = false
      end

      response.reply("Next round! Recover 5 motes.")
      robot.trigger(:list_order, room: room)
    end

    # Display the initiative order.
    def show(response)
      log.debug("Triggering #act")
      robot.trigger(:list_order, room: response.message.source.room_object)
    end

    # Remove all characters from the room.
    # Post a message that combat has ended.
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

    ### Helpers

    # Get the character name (quoted or not) and the current chat room.
    private def get_name_and_room(response)
      name = response.match_data.named_captures["name"] || response.match_data.named_captures["name_quoted"]
      room = response.message.source.room_object
      [name, room]
    end

    # If the character exists, call the block on it. Otherwise, send an error message.
    private def with_character(robot, redis, room, name, &block)
      character = Ex3Bot::Character.new(redis, room.id, name)
      if character.exists?
        block.call(character)
      else
        robot.send_message(Lita::Source.new(room: room), "Name not found: #{name}")
      end
    end
  end

  Lita.register_handler(Ex3)
end
