=begin
  mail/mail.rb - mail utilities
=end

require 'kagemai/kconv'
require 'kagemai/config'
require 'kagemai/project'
require 'kagemai/error'
require 'kagemai/mode'
require 'kagemai/util'
require 'kagemai/fold'

require 'rmail/address'

module RMail
  class Address
    def self.validate(str)
      addr, = self.parse(str)
      return false unless addr
      
      addr.domain.include?('.')
    end
  end
end

module Kagemai
  class MessageID
    def initialize(project_id, report_id, message_id, salt, smtp_server = Config[:smtp_server])
      @project_id = project_id
      @report_id = report_id
      @message_id = message_id
      @salt = salt
      @smtp_server = smtp_server
    end
    attr_reader :project_id, :report_id, :message_id, :salt, :smtp_server

    def to_s()
      "<#{@project_id}.#{@report_id}.#{@message_id}.#{@salt}@#{@smtp_server}>"
    end

    def self.parse(str)
      return nil if str.to_s.empty?

      re = /<(#{Project::ID_REGEXP_STR})\.(\d+)\.(\d+)\.(\d+)@(.*)>/

      result = nil
      if re =~ str.strip then
        result = MessageID.new($1, $2, $3, $4, $5)
      end

      result
    end

  end

  class Mail
    def initialize(to, cc, bcc, reply_to, project, report, message)
      @lang = project.lang
      
      @to = to
      @cc = cc
      @bcc = bcc
      @reply_to = reply_to
      
      @from = message['email']
      
      subject = make_subject(project.subject_id_figure, project.id, report.id, message)
      @subject = subject

      project_name = Mail.b_encode(project.name)
      date = Mail.rfc2822_date_time(message.time)
      message_id = MessageID.new(project.id, report.id, message.id, message.time.to_i).to_s
      references = nil

      if message.id >= 2 then
        pmessage = report.at(message.id - 1)
        references = MessageID.new(project.id, report.id, message.id - 1, pmessage.time.to_i).to_s
      end

      @header = Util.eval_template('report_h.rtxt', 
                                   project.template_dir, 
                                   project.lang, 
                                   binding).gsub(/\n\n+/m, "\n")
      
      url_param = "project=#{project.id}&action=view_report&id=#{report.id}"
      report_url = "#{Config[:base_url]}#{Mode::GUEST.url}?#{url_param}"
      message_detail = make_message_detail(message)

      message_body = message['body'].collect {|line|
        (/^([>+-=!\s]|RCS file:)/ =~ line) ? line : Fold.fold(line)
      }.join('')

      @body = Util.eval_template('report_b.rtxt', 
                                 project.template_dir, 
                                 project.lang, 
                                 binding)
      if @lang == 'ja' then
        @body = KKconv.conv(@body, KKconv::JIS, KKconv::UTF8)
      end
    end
    
    attr_reader :from, :reply_to, :header, :body
    attr_reader :to, :cc, :bcc, :subject
    
    def to_s()
      "#{@header}\n#{@body}".gsub(/\n/m, "\r\n")
    end

    def to_addrs()
      @to + @cc + @bcc
    end

    def make_subject(id_figure, project_id, report_id, message)
      tag = subject_tag(id_figure, project_id, report_id)
      Mail.b_encode("#{tag} #{message['title']}")
    end

    def subject_tag(id_figure, project_id, report_id)
      if id_figure > 0 then
        fmt = "%0#{id_figure}d"
        '[' + project_id + ':' + sprintf(fmt, report_id) + ']'
      else
        ''
      end
    end

    def make_message_detail(message)
      ignore = ['email', 'title', 'body']
      
      max = 0
      message.type.each do |etype|
        next if etype.hide_from_guest?
        next if ignore.include?(etype.id)
        next if message[etype.id].to_s.empty?
        width = Fold.mbc_width(etype.name)
        max = width if width > max
      end
      
      detail = []
      message.type.each do |etype|
        next if etype.hide_from_guest?
        next if ignore.include?(etype.id)
        next if message[etype.id].to_s.empty?
        
        # note: 'name = "%-#{max}s" % etype.name' is not work correctly with UTF-8
        name = etype.name + (' ' * (max - Fold.mbc_width(etype.name)))
        
        unless etype.kind_of?(FileElementType) then
          detail << [name, message[etype.id].gsub(/,\n/, ', ')]
        else
          values = []
          message.element(etype.id).each do |attachment|
            values << "#{attachment.name} (#{attachment.mime_type}, #{attachment.size} bytes)"
          end
          detail << [name, values.join("\n%#{max}s" % ' ')]
        end
      end

      detail
    end


    PATTERN_UTF8  = '[\xc0-\xfd]'
    ENCODE_MARK_H = '=?ISO-2022-JP?B?'
    ENCODE_MARK_T = '?='
    
    def self.m_encode(str, limit = nil)
      unless limit then        
        pos = str.index(Regexp.new('\s*' + PATTERN_UTF8, nil, 'n'))
        if pos then
          # str includes UTF-8 multibyte character code.
          limit = 70 * 3 / 4 - ENCODE_MARK_H.size - ENCODE_MARK_T.size - 'Subject: '.size
        else
          limit = 70
        end
      end
      
      lines = Fold.fold_line(str, limit)
      encoded = lines.collect {|line| m_encode_line(line)}
      
      encoded.size > 0 ? encoded.join("\n ") : encoded[0]
    end
    
    def self.b_encode(str, limit = nil)
      m_encode(str, limit)
    end
    
    def self.m_encode_line(line)
      case Config[:language]
      when 'ja'
        b_encode_line(line)
      else
        q_encode_line(line)
      end
    end
    
    def self.b_encode_line(line)
      line = line.sub(/\n/, '')
      pos = line.index(Regexp.new('\s*' + PATTERN_UTF8, nil, 'n'))
      if pos then
        ascii_part = pos > 0 ? line[0..pos-1] : ''
        jis_part = KKconv::conv(line[pos..line.length], KKconv::JIS, KKconv::UTF8)
        encoded_part = [jis_part].pack('m').gsub(/\n/, '')
        sep = ascii_part.empty? ? '' : ' '
        "#{ascii_part}#{sep}#{ENCODE_MARK_H}#{encoded_part}#{ENCODE_MARK_T}"
      else
        line
      end
    end
    
    def self.q_encode_line(line)
      line = line.sub(/\n/, '')
      pos = line.index(Regexp.new('\s*' + PATTERN_UTF8, nil, 'n'))
      if pos then
        ascii_part = pos > 0 ? line[0..pos-1] : ''
        encoded_part = [line[pos..line.length]].pack('M').gsub(/\n/, '')
        sep = ascii_part.empty? ? '' : ' '
        "#{ascii_part}#{sep}=?UTF-8?Q?#{encoded_part}?="
      else
        line
      end
    end

    def self.m_decode(str)
      result = ''
      
      first = true
      str.each_line do |line|
        l = first ? line.sub(/[\r\n]+/m, '') : line.strip
        first = false
        
        encoding = nil
        l.gsub!(/=\?(.*?)\?(B|Q)\?([!->@-~]+)\?=/i) do
          encoding = $1
          if $2 == 'B' then
            $3.unpack('m')[0]
          else
            $3.unpack('M')[0]
          end
        end
        l = KKconv.ckconv(l, 'utf8', encoding) if encoding
        result += l
      end
      
      result
    end

    def self.b_decode(str)
      m_decode(str)
    end
    
    DAY_NAME   = %w(Sun Mon Tue Wed Thu Fri Sat Sun)
    MONTH_NAME = %w(ZERO Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
    
    def self.rfc2822_date_time(tm)
      # calculate offset from UTC. [ruby-dev:7928]
      ut = tm.clone.utc
      offset = (tm.to_i - Time.local(*ut.to_a[0, 6].reverse).to_i) / 60
      offset_h, offset_m = offset.divmod(60)
      
      day_of_week = DAY_NAME[tm.wday]
      date = sprintf('%.2d %s %.4d', tm.mday, MONTH_NAME[tm.month], tm.year)
      time = sprintf('%.2d:%.2d:%.2d', tm.hour, tm.min, tm.sec)
      zone = sprintf('%+.2d%.2d', offset_h, offset_m)
      
      "#{day_of_week}, #{date} #{time} #{zone}"
    end

  end
end
