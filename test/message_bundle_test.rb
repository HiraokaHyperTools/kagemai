require 'test/unit'
require 'kagemai/message_bundle'

class TestMessageBundle < Test::Unit::TestCase
  include Kagemai

  def setup()
    @filename = File.dirname(__FILE__) + '/test_messages'
    File.open(@filename, 'wb') do |file|
      file.puts "# skip this"
      file.puts "test_key1 = hello world"
      file.puts "test_key2 = hello world2"
      file.puts "test_key3 = hello = world"
    end
    @mb = MessageBundle.new(@filename, 'ja', false)
  end
  
  def teardown()
    File.unlink(@filename)
  end

  def test_get_message()
    assert_equal('hello world', @mb[:test_key1])
  end

  def test_get_message2()
    assert_raise(NoSuchResourceError) {
      @mb[:test_key4]
    }
  end

  def test_get_message_3()
    MessageBundle.open('test/testfile/message', 'ja', 'testmessage', false)
    assert_equal('hello world', MessageBundle[:test_key1])
  end

  def test_get_message4()
    assert_equal('hello = world', @mb[:test_key3])
  end

  def test_update()
    messages2 = <<-MESSAGES2
    # skip this
    test_key1 = hello world3
    test_key3 = hello = world5
    MESSAGES2

    @mb.update(messages2)

    assert_equal('hello world3', @mb[:test_key1])
    assert_equal('hello world2', @mb[:test_key2])
    assert_equal('hello = world5', @mb[:test_key3])
  end
end

