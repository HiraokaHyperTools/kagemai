require 'test/unit'
require 'kagemai/cgi/form_handler'

class TestFormHandler < Test::Unit::TestCase
  include Kagemai::FormHandler
  
  def test_valid_email_address()
    addresses = [
      'fukuoka@daifukuya.com',
      'fukuoka-t@daifukuya.com',
      'fukuoka_t@daifukuya.com',
      'fukuoka@d-aifukuya.com',
      'fukuoka@d_aifukuya.com',
    ]

    addresses.each do |address|
      unless valid_email_address?(address)
        fail("invalid address = #{address.inspect}")
      end
    end
  end

  def test_valid_email_address2()
    iv_addresses = ['fukuoka']
    
    iv_addresses.each do |iv_address|
      if valid_email_address?(iv_address)
        fail("valid address = #{iv_address.inspect}")
      end
    end
  end

end
