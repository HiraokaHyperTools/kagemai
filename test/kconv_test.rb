require 'test/unit'

require 'kconv'
require 'kagemai/kconv'

class TestKconv < Test::Unit::TestCase
  include Kagemai

  def setup()
  end
  
  def teardonw()
  end
  
  def test_translate_with_mime()
    input = "test \n =?ISO-2022-JP?B?GyRCJUYlOSVIGyhC?="
    output = KKconv::conv(input, KKconv::JIS, KKconv::UTF8)
    assert_equal(input, output)
  end
  
end
