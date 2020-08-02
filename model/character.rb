module Ex3Bot
  class Character
    def self.all_in_room(redis, r)
      characters = []
      redis.scan_each(:match => "room:#{r}|*") do |key|
        name = redis.hget(key, "name")
        characters << Ex3Bot::Character.new(redis, r, name)
      end
      characters
    end

    def initialize(redis, room, name)
      @redis = redis
      @room = room
      @safe_name = safe_name(name)
    end

    def self.create!(redis, room, name)
      character = Ex3Bot::Character.new(redis, room, name)
      character.name!(name)
      character
    end

    private def safe_name(raw_name)
      raw_name.gsub(/\W/, "_").downcase
    end

    private def record_key
      "room:#{@room}|name:#{@safe_name}"
    end

    def exists?
      @redis.exists?(record_key)
    end

    def name!(n)
      @redis.hset(record_key, "name", n)
    end

    def name(raw=@redis.hget(record_key, "name"))
      raw.to_s
    end

    def initiative!(i)
      @redis.hset(record_key, "initiative", i)
    end

    def initiative(raw=@redis.hget(record_key, "initiative"))
      raw.to_i
    end

    def acted!(a)
      @redis.hset(record_key, "acted", a ? "y" : "n")
    end

    def acted(raw=@redis.hget(record_key, "acted"))
      raw == "y"
    end

    def delete!
      @redis.del(record_key)
    end

    def to_s
      fields = @redis.hgetall(record_key)
      display = {}
      display[:initiative] = initiative(fields["initiative"]).to_s.rjust(3)
      display[:name] = name(fields["name"]).to_s

      "`#{display[:initiative]}` **#{display[:name]}**"
    end
  end
end
