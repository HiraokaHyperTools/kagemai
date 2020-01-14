require 'test/unit'

require 'kagemai/kagemai'
require 'kagemai/project'
require 'kagemai/message'
require 'kagemai/message_bundle'

module Kagemai
  remove_const(:VERSION)
  remove_const(:CODENAME)
  VERSION  = 'TEST_VERSION'
  CODENAME = 'TEST_CODENAME'
  Config[:smtp_server] = 'localhost'
end

class TestProject < Test::Unit::TestCase
  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
    @project_dir = 'test/testfile/projects'
    @project = Kagemai::Project.open(@project_dir, 'p1')
    @project.db_manager.disable_cache

    @m1 = Kagemai::Message.new(@project.report_type)
    @m2 = Kagemai::Message.new(@project.report_type)

    @id_filename = @project_dir + '/p1/spool/id'
    File.open(@id_filename, 'w') do |file|
      file.puts '2'
    end
  end

  def teardown
    File.unlink(@id_filename)

    (2..6).each do |i|
      if FileTest.exist?(@project_dir + "/p1/spool/#{i}")
        Dir.glob(@project_dir + "/p1/spool/#{i}/*") do |f|
          File.unlink(f.untaint)
        end
        Dir.rmdir(@project_dir + "/p1/spool/#{i}")
      end
    end
  end

  def test_open
    assert_equal('p1', @project.id)
    assert_equal('test project 1', @project.name)
  end

  def test_load
    report = @project.load_report(1)
    assert_instance_of(Kagemai::Report, report)
  end

  def test_new_report
    size = @project.size
    report = @project.new_report(@m1)
    assert_instance_of(Kagemai::Report, report)
    assert_equal(size + 1, @project.size)
    assert_equal(1, report.size)
  end

  def test_add_message
    size = @project.size
    report = @project.new_report(@m1)
    assert_equal(size + 1, @project.size)
    assert_equal(1, report.size)

    report2 = @project.add_message(report.id, @m2)
    assert_equal(2, report2.size)
  end

  def test_collect_reports
    m1 = Kagemai::Message.new(@project.report_type)
    m2 = Kagemai::Message.new(@project.report_type)
    m1['status'] = '新規'
    m2['status'] = '新規'

    m3 = Kagemai::Message.new(@project.report_type)
    m4 = Kagemai::Message.new(@project.report_type)
    m3['status'] = '修正済み'
    m4['status'] = '修正済み'

    m5 = Kagemai::Message.new(@project.report_type)
    m5['status'] = '完了'

    @project.new_report(m1)
    @project.new_report(m2)
    @project.new_report(m3)
    @project.new_report(m4)
    @project.new_report(m5)

    report_hash = @project.collect_reports('status')
    assert_equal(3, report_hash.size)
    assert(report_hash.has_key?('新規'))
    assert(report_hash.has_key?('修正済み'))
    assert(report_hash.has_key?('完了'))
    assert_equal(3, report_hash['新規'].size)
    assert_equal(2, report_hash['修正済み'].size)
    assert_equal(1, report_hash['完了'].size)
    assert_equal('新規', report_hash['新規'][0].attr('status'))
    assert_equal('修正済み', report_hash['修正済み'][0].attr('status'))
    assert_equal('完了', report_hash['完了'][0].attr('status'))
  end


  class DummyMailer
    def sendmail(mail, from_addr, *to_addrs)
      @mailsrc = mail.to_s
      @from_addr = from_addr
      @to_addrs = *to_addrs
    end
    attr_reader :mailsrc, :from_addr, :to_addrs
  end

  def test_sendmail()
    mailer = DummyMailer.new
    Kagemai::Mailer.set_mailer(mailer)
    
    @project.instance_eval{
      @admin_address = 'kagemai-admin@daifukuya.com'
      @post_address  = 'kagemai-bts@daifukuya.com'
      @notify_addresses = ['notify1@daifukuya.com']
    }
    
    @m1['email'] = 'fukuoka@daifukuya.com'
    @m1['title'] = 'sendmail test'
    @m1['status'] = '新規'
    @m1['body'] = 'hello world'
    @m1.time = Time.local(2002, 12, 27, 15, 15, 32)
    @m1.set_option('email_notification', true)
    
    @project.new_report(@m1)
    
    expect_mail = ''
    File.open("#{@project_dir}/p1/expect_mail.txt") {|file| expect_mail = file.read.gsub(/\r/, '')}
    expect_mail = Kconv.kconv(expect_mail, Kconv::JIS, Kconv::UTF8).gsub(/\n/, "\r\n")
    
    expect_from_addr = @project.admin_address
    expect_to_addrs  = ['fukuoka@daifukuya.com', 'notify1@daifukuya.com']
    
    assert_equal(expect_mail, mailer.mailsrc)
    assert_equal(expect_from_addr, mailer.from_addr)
    assert_equal(expect_to_addrs, mailer.to_addrs)
  end

end

