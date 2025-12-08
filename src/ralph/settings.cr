module Ralph
  # Global settings for the ORM
  class Settings
    property database : Database::Backend?

    def initialize
    end
  end

  @@settings = Settings.new

  def self.settings : Settings
    @@settings
  end

  def self.settings=(value : Settings)
    @@settings = value
  end
end

require "./database"
