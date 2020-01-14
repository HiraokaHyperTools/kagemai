require 'test/unit'
require 'kagemai/message'
require 'kagemai/reporttype'
require 'kagemai/elementtype'
require 'kagemai/message_bundle'

class TestMessage < Test::Unit::TestCase
  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
    @eid = 'email'
    @rtype = Kagemai::ReportType.new()
    @rtype.add_element_type(Kagemai::ElementType.new({'id' => @eid, 'name' => 'email address'}))
    @rtype.add_element_type(Kagemai::ElementType.new({'id' => 'type', 'name' => 'message type'}))
    @rtype.add_element_type(Kagemai::ElementType.new({'id' => 'body', 'name' => 'body'}))
    @mid = 1
    @message = Kagemai::Message.new(@rtype, @mid)
  end

  def test_new
    assert_instance_of(Kagemai::Message, @message)
    assert_equal(@rtype, @message.type)
    assert_equal(@mid, @message.id)
    element = @message.element(@eid)
    assert_equal(@eid, element.id)
    
    assert_respond_to(@message, :body)
  end

  def test_eaccess
    email = 'fukuoka@daifukuya.com'
    @message[@eid] = email
    assert_equal(email, @message[@eid])
  end

  def test_eaccess2
    assert_raise(Kagemai::NoSuchElementError) {
      @message['undefined element'] = 'foo'
    }
  end

  def test_eaccess3
    assert_raise(Kagemai::NoSuchElementError) {
      @message['undefined element']
    }
  end


  def test_option
    @message.set_option('myoption', 'hoge')
    assert_equal('hoge', @message.get_option('myoption'))
  end

  def test_option2
    assert_equal(nil, @message.get_option('myoption'))
  end

  def test_option3
    assert_equal('hello', @message.get_option('myoption', 'hello'))
  end

  def test_option_str
    @message.set_option('opt1', 'v1')
    @message.set_option('opt2', 'v2')
    assert_equal('opt1=v1,opt2=v2', @message.option_str())
  end

  def test_set_option_str
    @message.set_option_str('opt1=v1,opt2=v2')
    assert_equal('v1', @message.get_option('opt1'))
    assert_equal('v2', @message.get_option('opt2'))
  end

  def test_each_option
    opt = {
      'opt1' => 'value1',
      'opt2' => 'value2',
      'opt3' => 'value3'
    }

    opt.each do |k, v|
      @message.set_option(k, v)
    end

    result = {}
    @message.each_option do |k, v|
      result[k] = v
    end

    assert_equal(opt, result)
  end

end

