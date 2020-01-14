=begin
  Element - message element class
=end

module Kagemai
  class Element
    def initialize(type, message, value = nil)
      @message = message
      @type = type
      @value = value ? value : type.default
      
      @type.element_created(self)
    end
    attr_reader :type, :message
    attr_accessor :value
    
    def id()
      @type.id
    end
    
    def method_missing(name, *args)
      @type.send(name, self, *args)
    end
  end
end
