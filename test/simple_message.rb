require 'kagemai/elementtype'

class SimpleMessage
  def initialize(id, value)
    @id = id
    @value = value
    @type = [Kagemai::ElementType.new({'id' => 'id', 'name' => 'name'})]
    @report = nil
  end
  attr_reader :value, :type
  attr_accessor :id, :report

  def [](key)
    @value[key]
  end
  
  def hide?()
    false
  end
  
  def element(key)
    SimpleMessage.new(key, @value[key])
  end

  def modified?() true end
end
