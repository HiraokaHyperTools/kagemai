require 'test/unit'
require 'kagemai/element'
require 'kagemai/elementtype'
require 'kagemai/message_bundle'

class TestElement < Test::Unit::TestCase
  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
    @eid = 'email'
    @etype = Kagemai::ElementType.new({'id' => @eid, 'name' => 'email address'})
  end

  def test_new()
    element = Kagemai::Element.new(@etype, nil)
    assert_instance_of(Kagemai::Element, element)
    assert_equal(@etype, element.type)
    assert_equal(@eid, element.id)
    assert_nil(element.value)
  end

  def test_new2()
    value = 'value'
    element = Kagemai::Element.new(@etype, nil, value)
    assert_equal(@eid, element.id)
    assert_equal(value, value)
  end

  def test_value=()
    element = Kagemai::Element.new(@etype, nil)
    assert_nil(element.value)
    value = 'v of bar'
    element.value = value
    assert_equal(value, element.value)
  end
end

