=begin
  Logger - Debug log class
=end

module Kagemai
  class Logger
    @@instance = nil
    def self.instance()
      @@instance = self.new unless @@instance
      @@instance
    end
    
    level = Struct.new('Level', :value, :name)
    DEBUG = level.new(0, 'DEBUG')
    WARN  = level.new(1, 'WARN ')
    ERROR = level.new(2, 'ERROR')
    FATAL = level.new(3, 'FATAL')

    def initialize()
      @level = ERROR
      @categories = Array.new
      @buffer = ''
    end
    attr_accessor :level
    attr_reader :buffer

    def add_category(category)
      @categories << category
    end

    def log(level, category, str)
      if @level.value <= level.value && @categories.include?(category) then
        @buffer += Logger.format(level, category, str)
      end
    end

    def clear()
      @buffer = ''
      @categories = Array.new
    end

    def self.format(level, category, str)
      level.name + ' ' + category + ': ' + str + "\n"
    end

    def self.log(level, category, str)
      instance().log(level, category, str)
    end

    def self.debug(category, str)
      log(DEBUG, category, str)
    end

    def self.warn(category, str)
      log(WARN, category, str)
    end

    def self.error(category, str)
      log(ERROR, category, str)
    end

    def self.fatal(category, str)
      log(fatal, category, str)
    end
    
    def self.level=(level)
      instance().level = level
    end

    def self.add_category(category)
      instance().add_category(category)
    end

    def self.buffer()
      instance().buffer
    end

    def self.clear()
      instance().clear()
    end

 end
end
