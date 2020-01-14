require 'test/unit'
require 'kagemai/cgi/htmlhelper'


class TestString < Test::Unit::TestCase
  def test_href()
    assert_equal('<a href="hello.html">hello world</a>',
                  'hello world'.href('hello.html'))
  end

  def test_href2()
    str = 'hello world'
    href = '"hello.html?name=n&amp;hoge=hagu"'
    assert_equal("<a href=#{href}>#{str}</a>",
                  'hello world'.href('hello.html', {'name' => 'n', 'hoge' => 'hagu'}))
  end

  def test_tag()
    str = 'hello world'
    assert_equal('<mytag>' + str + '</mytag>', str.tag('mytag'))
  end

  def test_tag2()
    str = 'hello world'
    assert_equal('<mytag name="hagu">' + str + '</mytag>', str.tag('mytag', {'name' => 'hagu'}))
  end
end
