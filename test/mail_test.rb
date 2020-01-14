require 'test/unit'

require 'kconv'
require 'kagemai/kconv'

require 'kagemai/reporttype'
require 'kagemai/message_bundle'
require 'kagemai/report'
require 'kagemai/message'
require 'kagemai/mail/mail'

require 'kagemai/kagemai'

module Kagemai
  remove_const(:VERSION)
  remove_const(:CODENAME)
  VERSION  = 'TEST_VERSION'
  CODENAME = 'TEST_CODENAME'
  Config[:smtp_server] = 'localhost'
end

class TestMailUtil < Test::Unit::TestCase
  include RMail

  def test_validate
    assert(Address.validate('fukuoka@daifukuya.com'))
    assert(!Address.validate('fukuoka'))
    assert(!Address.validate('fukuoka@daifukuya'))
    assert(!Address.validate('fukuoka@daifukuya.'))
    assert(!Address.validate('fukuoka@daifukuya.'))
    assert(!Address.validate(''))
    assert(!Address.validate(nil))
  end
end

class TestMessageID < Test::Unit::TestCase
  include Kagemai
  
  def setup
    @project_id = 'test_id'
    @report_id  = '123'
    @message_id = '456'
  end

  def test_new
    msgid = MessageID.new('test_id', '123', '456', '789')
    assert_equal('<test_id.123.456.789@localhost>', msgid.to_s)
  end

  def test_parse
    msgid = MessageID.parse('<test_id.123.456.789@localhost>')
    assert_equal('test_id', msgid.project_id)
    assert_equal('123', msgid.report_id)
    assert_equal('456', msgid.message_id)
    assert_equal('789', msgid.salt)
    assert_equal('localhost', msgid.smtp_server)
  end

  def test_parse_err
    msgid = MessageID.parse('<test_id.123.456.@localhost>')
    assert_equal(nil, msgid)
  end
end

class TestMail < Test::Unit::TestCase
  include Kagemai

  class DummyProject
    def initialize()
      @id = 'test_project'
      @name = 'test project'
      @template_dir = ''
      @lang = 'ja'
      @subject_id_figure = 4
      @notify_addresses = []
      @admin_address = 'kagemai-admin@daifukuya.com'
      @post_address = ''
    end
    attr_reader :id, :name, :template_dir, :lang, :subject_id_figure
    attr_accessor :notify_addresses, :admin_address, :post_address
  end

  def setup
    MessageBundle.open('resource', 'ja', 'messages', false)

    @project = DummyProject.new()
    @rtype = ReportType.load('test/testfile/rtype1.xml')

    @message = Message.new(@rtype, 1)
    @message['email'] = 'fukuoka@daifukuya.com'
    @message['title'] = 'test subject'
    @message['status'] = '新規'
    @message['priority'] = '緊急'
    @message['category'] = "c1,\nc2"
    @message['body'] = 'hello world!'
    @message.time = Time.local(2002, 12, 27, 15, 15, 32)
    @message.set_option('email_notification', 'opt_v1')
    
    @report = Report.new(@rtype, 1)
    @report.add_message(@message)
    
    @to = ['fukuoka@daifukuya.com', 'fukuoka2@daifukuya.com']
    @cc = []
    @bcc = @project.notify_addresses
    @reply_to = @project.post_address

    @mail1 = Mail.new(@to, @cc, @bcc, @reply_to, @project, @report, @message)

    @message2 = @message.dup
    @message2.id = 2

    @mail2 = Mail.new(@to, @cc, @bcc, @reply_to, @project, @report, @message2)
  end
  
  def test_new
    expect = ''
    File.open('test/testfile/expect_header1.txt') {|file| expect = file.read.gsub(/\r/, '')}
    assert_equal(expect, @mail1.header)
  end

  def test_new2
    expect = ''
    File.open('test/testfile/expect_body1.txt') {|file| expect = file.read.gsub(/\r/, '')}
    expect = Kconv.kconv(expect, Kconv::JIS, Kconv::UTF8)

    assert_equal(expect, @mail1.body)
  end

  def test_new3
    @message['title'] = 'ながいながいタイトルをもったテストメールを書いてみようかと思った。こんなもんでどうでしょうか？'
    mail = Mail.new(@to, @cc, @bcc, @reply_to, @project, @report, @message)

    expect = ''
    File.open('test/testfile/expect_header2.txt') {|file| expect = file.read.gsub(/\r/, '')}
    assert_equal(expect, mail.header)
  end

  def test_new4
    expect = ''
    File.open('test/testfile/expect_header3.txt') {|file| expect = file.read.gsub(/\r/, '')}
    assert_equal(expect, @mail2.header)
  end

  def test_to_s
    expect = ''
    File.open('test/testfile/expect_header1.txt') {|file| expect = file.read.gsub(/\r/, '')}
    expect += "\n"
    File.open('test/testfile/expect_body1.txt') {|file| expect += file.read.gsub(/\r/, '')}
    expect = Kconv.kconv(expect, Kconv::JIS, Kconv::UTF8).gsub(/\n/m, "\r\n")

    assert_equal(expect, @mail1.to_s)
  end

  def test_body_fold
    m1 = "ながいながいメッセージを持ったメールを書いてみようかと思った。" + 
         "こんなもんでどうでしょうか。"
    
    prefix = [">", " ", "+", "-", "=", "!", "RCS file:"]

    @message['body'] = m1 + "\n" + prefix.collect {|p| p + " " + m1}.join("\n")
    mail = Mail.new(@to, @cc, @bcc, @reply_to, @project, @report, @message)

    expect = ''
    File.open('test/testfile/expect_body2.txt') {|file| expect = file.read.gsub(/\r/, '')}
    
    body =  Kconv.kconv(mail.body, Kconv::UTF8, Kconv::JIS)
    
    assert_equal(expect, body)
  end


  def test_rfc2822_date_time
    tm = Time.local(2002, 12, 27, 15, 15, 32)
    assert_equal('Fri, 27 Dec 2002 15:15:32 +0900', Mail.rfc2822_date_time(tm))
  end

  def test_b_encode
    src = 'test 3'
    assert_equal(src, Mail.b_encode(src))
  end

  def test_b_encode2
    src = 'テスト２'
    assert_equal('=?ISO-2022-JP?B?GyRCJUYlOSVIIzIbKEI=?=', Mail.b_encode(src))
  end

  def test_b_encode3
    src = 'test テスト２'
    assert_equal('test =?ISO-2022-JP?B?IBskQiVGJTklSCMyGyhC?=', Mail.b_encode(src))
  end

  def test_b_encode4
          #1234567890123
    src = 'test1 test2'
    expect = "test1 \n test2"
    assert_equal(expect, Mail.b_encode(src, 7))
  end

  def test_b_encode5
          #1234567890123
    src = 'test テスト'
    expect = "test \n =?ISO-2022-JP?B?GyRCJUYlOSVIGyhC?="
    assert_equal(expect, Mail.b_encode(src, 6))
  end

  def test_b_encode6
    src = 'test テストのごとく今日はさらさらと流れる'

    s1 = 'test テストのご'
    s2 = 'とく今日はさら'
    s3 = 'さらと流れる'
    expect = [s1, s2, s3].collect {|s| Mail.b_encode(s)}.join("\n ")

    assert_equal(expect, Mail.b_encode(src, 15))
  end

  def test_b_encode7
    src = '[test:017] OpenSSH-3.6.1p2' # BTS:125
    assert_equal(src, Mail.b_encode(src))
  end
  
  def test_q_encode1
          #1234567890123
    src = 'test テスト'
    expect = "test =?UTF-8?Q?" + [' テスト'].pack('M').gsub("\n", '') + "?="
    assert_equal(expect, Mail.q_encode_line(src))
  end
  
  def test_q_encode2
    src = 'テスト'
    expect = "=?UTF-8?Q?" + ['テスト'].pack('M').gsub("\n", '') + "?="
    assert_equal(expect, Mail.q_encode_line(src))
  end

  def test_m_encode1
    src = 'テスト'
    jis = Kconv.kconv('テスト', Kconv::JIS, Kconv::UTF8)
    expect = "=?ISO-2022-JP?B?" + [jis].pack('m').gsub("\n", '') + "?="
    assert_equal(expect, Mail.m_encode(src))
  end
  
  def test_m_encode2
    src = 'テスト'
    expect = "=?UTF-8?Q?" + ['テスト'].pack('M').gsub("\n", '') + "?="
    lang = Kagemai::Config[:language]
    begin
      Kagemai::Config[:language] = 'en'
      assert_equal(expect, Mail.m_encode(src))
    ensure
      Kagemai::Config[:language] = lang
    end
  end
  
  def test_decode1
    src = "test \n =?ISO-2022-JP?B?GyRCJUYlOSVIGyhC?="
    expect = 'test テスト'
    assert_equal(expect, Mail.b_decode(src))
  end
  
  def test_decode2
    expect = 'テスト'
    encode_part = [Kconv.kconv(expect, Kconv::JIS, Kconv::UTF8)].pack('m').gsub("\n", '')
    src = "=?ISO-2022-JP?B?" + encode_part + "?="
    assert_equal(expect, Mail.m_decode(src))
  end
  
  def test_decode3
    expect = 'テスト'
    encode_part = [expect].pack('m').gsub("\n", '')
    src = "=?UTF-8?B?" + encode_part + "?="
    assert_equal(expect, Mail.m_decode(src))
  end
  
  def test_decode4
    expect = 'テスト'
    encode_part = [expect].pack('M').gsub("\n", '')
    src = "=?UTF-8?Q?" + encode_part + "?="
    assert_equal(expect, Mail.m_decode(src))
  end
  
end
