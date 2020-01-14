require 'test/unit'
require 'kagemai/report'
require 'kagemai/reporttype'
require 'kagemai/elementtype'
require 'kagemai/message_bundle'
require 'kagemai/message'
require 'test/simple_message'

class TestReport < Test::Unit::TestCase
  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
    @eid = 'email'
    @rtype = Kagemai::ReportType.new()
    @rtype.add_element_type(Kagemai::ElementType.new({'id' => @eid, 'name' => 'email address'}))
    @rtype.add_element_type(Kagemai::ElementType.new({'id' => 'type', 'name' => 'report_type'}))

    @rid = 1
    @report = Kagemai::Report.new(@rtype, @rid)
  end

  def test_new
    assert_instance_of(Kagemai::Report, @report)
    assert_equal(@rtype, @report.type)
    assert_equal(@rid, @report.id)
  end

  def test_add_message
    assert_equal(0, @report.size)
    @report.add_message(SimpleMessage.new('m1', 'm1'))
    @report.add_message(SimpleMessage.new('m2', 'm2'))
    assert_equal(2, @report.size)
  end

  def test_first
    m1 = SimpleMessage.new('m1', 'm1')
    @report.add_message(m1)
    @report.add_message(SimpleMessage.new('m2', 'm2'))
    assert_equal(m1, @report.first)
  end

  def test_last
    m2 = SimpleMessage.new('m2', 'm2')
    @report.add_message(SimpleMessage.new('m1', 'm1'))
    @report.add_message(m2)
    assert_equal(m2, @report.last)
  end

  def test_get_attr
    @report.add_message(SimpleMessage.new('m1', {'name' => 'fukuoka'}))
    @report.add_message(SimpleMessage.new('m2', {'name' => 'tomoyuki'}))
    assert_equal('tomoyuki', @report.attr('name'))
  end

  def test_get_attr2
    @report.add_message(SimpleMessage.new('m1', {'email' => 'fukuoka'}))
    assert_equal('fukuoka', @report.attr('email'))
  end

  def test_each
    expect = [
      SimpleMessage.new('m1', 'm1'), 
      SimpleMessage.new('m2', 'm2')
    ]
    expect.each do |m|
      @report.add_message(m)
    end

    result = []
    @report.each do |m|
      result << m
    end
    assert_equal(expect, result)
  end

  def test_email_addresses
    addresses = [
      'fukuoka@daifukuya.com',
      'tomoyuki@daifukuya.com',
      'hoge@daifukuya.com'
    ]
    notification = [true, false, true]


    addresses.each_with_index do |addr, i|
      message = Kagemai::Message.new(@rtype, 1)
      message['email'] = addr
      message.set_option('email_notification', notification[i])
      @report.add_message(message)
    end

    assert_equal([addresses[0], addresses[2]], @report.email_addresses())
  end

  def test_email_addresses2
    addresses = [
      'fukuoka@daifukuya.com',
      'tomoyuki@daifukuya.com',
      'hoge@daifukuya.com',
      'fukuoka@daifukuya.com'
    ]
    notification = [true, false, true, false]


    addresses.each_with_index do |addr, i|
      message = Kagemai::Message.new(@rtype, 1)
      message['email'] = addr
      message.set_option('email_notification', notification[i])
      @report.add_message(message)
    end

    assert_equal([addresses[2]], @report.email_addresses())
  end

  def test_email_addresses3
    addresses = [
      'fukuoka@daifukuya.com',
      'tomoyuki@daifukuya.com',
      'hoge@daifukuya.com',
      'fukuoka@daifukuya.com',
      'fukuoka@daifukuya.'
    ]
    notification = [true, false, true, false, true]


    addresses.each_with_index do |addr, i|
      message = Kagemai::Message.new(@rtype, 1)
      message['email'] = addr
      message.set_option('email_notification', notification[i])
      @report.add_message(message)
    end

    assert_equal([addresses[2]], @report.email_addresses())
  end

end

