require 'test/unit'

require 'bin/mailif'

require 'kagemai/project'
require 'kagemai/report'
require 'kagemai/message'

class TestMailApp < Test::Unit::TestCase
  include Kagemai

  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
    @project_id = 'p1'
    @project_dir = 'test/testfile/projects'
    @id_filename = @project_dir + '/p1/spool/id'

    @mailapp = MailApp.new(@project_id, 'ja', @project_dir)

    @project = Project.open(@project_dir, @project_id)
    File.open(@id_filename, 'w') do |file|
      file.puts '2'
    end

    if $WIN32 then
      $LOGFILE = ENV['TEMP'] + '/kagemai.log'
      $LOGFILE.untaint
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

    seqfile = 'test/testfile/projects/p1/spool/attachments/seq'
    Dir.glob('test/testfile/projects/p1/spool/attachments/*') do |name|
      next if name.include?('DO_NOT_REMOVE')
      next if name.include?('CVS')
      File.unlink(name.untaint)
    end

    Dir.glob('test/testfile/projects/p1/mail/*') do |name|
      next if name.include?('DO_NOT_REMOVE')
      next if name.include?('CVS')
      File.unlink(name.untaint)
    end

    File.unlink($LOGFILE) if File.exist?($LOGFILE)
  end

  def test_get_report
    msg_id = '<p1.1.1.20020108@mail.daifukuya.com>'
    report = @mailapp.get_report(msg_id, '')
    assert_instance_of(Kagemai::Report, report)
    assert_equal(1, report.id)
  end

  def test_get_report2
    subject = '[p1:0001] test'
    report = @mailapp.get_report('', subject)
    assert_instance_of(Kagemai::Report, report)
    assert_equal(1, report.id)
  end

  def test_get_report3
    subject = '[p1:0087] test'
    begin
      report = @mailapp.get_report('', subject)
    rescue Kagemai::ParameterError
      return
    else
      assert_fail('no exception')
    end
  end

  def test_strip_subject_tag
    subject = 'hello world'
    assert_equal(subject, @mailapp.strip_subject_tag('[p1:0001]' + subject))
    assert_equal(subject, @mailapp.strip_subject_tag('[p1:0001] ' + subject))
    assert_equal(subject, @mailapp.strip_subject_tag('[p1:1] ' + subject))
    assert_equal(subject, @mailapp.strip_subject_tag('[p1:100] ' + subject))
  end

  def test_strip_subject_tag2
    subject = 'hello world'
    assert_equal(subject, @mailapp.strip_subject_tag('RE: [p1:0001]' + subject))
    assert_equal(subject, @mailapp.strip_subject_tag('RE: [p1:0001] ' + subject))
    assert_equal(subject, @mailapp.strip_subject_tag('RE: [p1:1] ' + subject))
    assert_equal(subject, @mailapp.strip_subject_tag('re: [p1:100] ' + subject))
    assert_equal(subject, @mailapp.strip_subject_tag('re: re: [p1:100] ' + subject))
    assert_equal(subject, @mailapp.strip_subject_tag('re^2: [p1:100] ' + subject))
  end

  def test_accept
    # test empty mail
    assert_raise(InvalidMailError) {
      @mailapp.accept('')
    }
  end

  def test_accept2
    size = @project.size

    File.open('test/testfile/mail/mail1.txt') {|f|
      str = f.read.gsub(/\r/, '').gsub(/\n/m, "\r\n")
      @mailapp.accept(str)
    }

    assert_equal(size + 1, @project.size)

    report = @project.load_report(@project.size)
    assert_equal(1, report.size)
    
    message = report.first
    assert_equal('fukuoka@daifukuya.com', message['email'])
    assert_equal('Mail Accept Test 1', message['title'])
    assert_equal("test mail accept 1.\nline 1.\nline 2.\n", message['body'])
  end

  def test_accept3
    size = @project.size

    File.open('test/testfile/mail/mail2.txt') {|f|
      @mailapp.accept(f)
    }

    assert_equal(size + 1, @project.size)

    report = @project.load_report(@project.size)
    assert_equal(1, report.size)
    
    message = report.first
    assert_equal('fukuoka@daifukuya.com', message['email'])
    assert_equal('メール受信テスト２', message['title'])
    assert_equal("test mail accept 2.\n今日はテスト日和\n", message['body'])
  end

  def test_accept4
    size = @project.size

    File.open('test/testfile/mail/mail3.txt') {|f|
      @mailapp.accept(f)
    }

    assert_equal(size + 1, @project.size)

    report = @project.load_report(@project.size)
    assert_equal(1, report.size)
    
    message = report.first
    assert_equal('fukuoka@daifukuya.com', message['email'])
    assert_equal('メール受信テスト３', message['title'])
    assert_equal("test mail accept 3.\n今日はテスト日和\n", message['body'])
  end

  def test_accept5
    msg_id = '<p1.1.1.20020108@mail.daifukuya.com>'

    size = @project.size

    File.open('test/testfile/mail/mail1.txt') {|f|
      @mailapp.accept(f)
    }

    File.open('test/testfile/mail/mail4.txt') {|f|
      @mailapp.accept(f)
    }

    assert_equal(size + 1, @project.size)

    report = @project.load_report(2)
    assert_equal(2, report.size)
    
    message = report.last
    assert_equal('tomoyuki@daifukuya.com', message['email'])
    assert_equal('Mail Accept Test 1', message['title'])
    assert_equal("メール返信のテスト\n", message['body'])
  end

  def test_accept6
    # test loop check
    assert_raise(InvalidMailError) {
      File.open('test/testfile/mail/mail5.txt') {|f|
        @mailapp.accept(f)
      }
    }
  end

  def test_accept7
    # test MIME mail. 1 plain/text & 1 application/octet-stream
    size = @project.size

    File.open('test/testfile/mail/mmail1.txt') {|f|
      @mailapp.accept(f)
    }

    assert_equal(size + 1, @project.size)

    report = @project.load_report(@project.size)
    assert_equal(1, report.size)
    
    message = report.first
    assert_equal('fukuoka@daifukuya.com', message['email'])
    assert_equal('MIME Accept Test 1', message['title'])
    assert_equal("test mail accept 1.\nline 1.\nline 2.\n", message['body'])

    fileinfo = nil
    message.element('attachment').each{|fi| fileinfo = fi }

    assert_equal('hoge.txt', fileinfo.name)

    assert_equal('application/octet-stream', fileinfo.mime_type)
    assert_equal(1, fileinfo.seq)
    
    attachment = @project.open_attachment(fileinfo.seq)
    begin
      assert_equal("hoge line1.\nhoge line2.", attachment.read)
    ensure
      attachment.close
    end
  end

  def test_accept8
    # test MIME mail. 1 plain/text & 2 application/octet-stream
    size = @project.size

    File.open('test/testfile/mail/mmail3.txt') {|f|
      @mailapp.accept(f)
    }

    assert_equal(size + 1, @project.size)

    report = @project.load_report(@project.size)
    assert_equal(1, report.size)
    
    message = report.first
    assert_equal('fukuoka@daifukuya.com', message['email'])
    assert_equal('MIME Accept Test 2', message['title'])
    assert_equal("test mail accept 2.\nline 1.\nline 2.\n", message['body'])

    fileinfo1 = message.element('attachment')[0]
    fileinfo2 = message.element('attachment')[1]

    assert_equal('hoge.txt', fileinfo1.name)
    assert_equal('application/octet-stream', fileinfo1.mime_type)
    assert_equal(1, fileinfo1.seq)

    attachment = @project.open_attachment(fileinfo1.seq)
    begin
      assert_equal("hoge line1.\nhoge line2.", attachment.read)
    ensure
      attachment.close
    end

    assert_equal('hoge2.txt', fileinfo2.name)
    assert_equal('application/octet-stream', fileinfo2.mime_type)
    assert_equal(2, fileinfo2.seq)

    attachment = @project.open_attachment(fileinfo2.seq)
    begin
      assert_equal("hoge line3.\nhoge line4.", attachment.read)
    ensure
      attachment.close
    end
  end

  def test_accept9
    # test MIME without text/plain part
    assert_raise(InvalidMailError) {
      File.open('test/testfile/mail/mmail2.txt') {|f|
        @mailapp.accept(f)
      }
    }
  end

  def test_accept10
    # test status change
    msg_id = '<p1.1.1.20020108@mail.daifukuya.com>'

    File.open('test/testfile/mail/mail1.txt') {|f|
      @mailapp.accept(f)
    }
    report = @project.load_report(2)
    assert_equal('新規', report.attr('status'))

    File.open('test/testfile/mail/mail6.txt') {|f|
      @mailapp.accept(f)
    }
    report = @project.load_report(2)
    assert_equal('未解決', report.attr('status'))
  end

  def test_accept11
    # test status change by name
    msg_id = '<p1.1.1.20020108@mail.daifukuya.com>'

    File.open('test/testfile/mail/mail1.txt') {|f|
      @mailapp.accept(f)
    }
    report = @project.load_report(2)
    assert_equal('新規', report.attr('status'))

    File.open('test/testfile/mail/mail7.txt') {|f|
      @mailapp.accept(f)
    }
    report = @project.load_report(2)
    assert_equal('未解決', report.attr('status'))
  end

  def test_accept12
    File.open('test/testfile/mail/mail8.txt') {|f|
      @mailapp.accept(f)
    }
    
    report = @project.load_report(@project.size)
    message = report.first
    assert_equal("UTF-8のテストですよ\n", message['body'])
  end

end
