require 'test/unit'

require 'kagemai/mail/mailer'

class DummyTestMailer
  def sendmail(mail, from_addr, *to_addrs)
    @mailsrc = mail.to_s
    @from_addr = from_addr
    @to_addrs = *to_addrs
  end
  attr_reader :mailsrc, :from_addr, :to_addrs
end

class TestMailer < Test::Unit::TestCase
  include Kagemai

  def test_send_mail
    mailer = DummyTestMailer.new
    Mailer.set_mailer(mailer)
    
    to_addrs = ['fukuoka', 'tomoyuki', 'fukuoka']

    Mailer.sendmail("test", 'fukuoka', *to_addrs)

    assert_equal(['fukuoka', 'tomoyuki'], mailer.to_addrs)
  end
end

class TestMailCommandMailer < Test::Unit::TestCase
  include Kagemai
  
  def test_new
    mailer = MailCommandMailer.new
    assert_instance_of(MailCommandMailer, mailer)
  end
end
