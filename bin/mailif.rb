#!/usr/bin/env ruby

=begin
  mailif.rb - KAGEMAI mail interface

  Copyright(C) 2002-2005 FUKUOKA Tomoyuki.

  This file is part of KAGEMAI.  

  KAGEMAI is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  $Id: mailif.rb 409 2008-02-23 14:07:23Z fukuoka $
=end

## usage: ruby mailif.rb project-id
##  * mailif.rb reads a mail from stdin.

kagemai_root = File.dirname(File.dirname(File.expand_path(__FILE__))).untaint # setup
config_file  = "#{kagemai_root}/html/kagemai.conf" # setup

if $0 == __FILE__ && ARGV.size == 3 then  
  project_id =  ARGV.shift
  opt = ARGV.shift
  if opt == '-c' then
    config_file = ARGV.shift
  end
  ARGV.unshift project_id
end

$:.unshift("#{kagemai_root}/lib")
require 'kagemai/config'
Kagemai::Config.initialize(kagemai_root, config_file)

$LOGFILE = "/tmp/mailif.log"  # setup
if File.exist?(config_file) then
  $LOGFILE = "#{Kagemai::Config[:project_dir]}/mailif.log"
end

require 'tempfile'

require 'rmail/parser'

require 'kagemai/kagemai'
require 'kagemai/kconv'
require 'kagemai/bts'
require 'kagemai/message_bundle'
require 'kagemai/error'
require 'kagemai/elementtype'
require 'kagemai/util'
require 'kagemai/mail/mail'
require 'kagemai/cgi/htmlhelper'
require 'kagemai/cgi/form_handler'

def log(message, another = nil)
  date = Time.now.to_s
  message = message.gsub(/\n/m, ("\n%#{date.size + 2}s" % ' '))

  log_message = "#{date}: #{message}"

  File.open($LOGFILE, 'a') do |file|
    file.flock(File::LOCK_EX)
    file.puts log_message
  end

  if another then
    another.puts log_message
  end
end


module Kagemai
  
  class MailApp

    def initialize(project_id, lang, project_dir = Config[:project_dir])
      MessageBundle.open(Config[:resource_dir], lang, Config[:message_bundle_name], false)
      @bts = BTS.new(project_dir)
      @project = @bts.open_project(project_id)
      
      Thread.current[:element_renderer] = {}
      script_dir = "#{@project.dir}/#{@project.id}/script"
      scripts = []
      Dir.glob("#{script_dir}/*.rb") do |name|
        src = File.open(name.untaint) {|file| file.read}
        scripts << [name, src.untaint]
      end
      
      thread = Thread.current
      Util.safe(1) {
        scripts.each do |script|
          name, src = script
          eval(src, binding, name) 
        end
      }
    end

    def accept(input)
      str = input.kind_of?(IO) ? input.read : input
      mail_message = RMail::Parser.new.parse(str.gsub(/\r\n/m, "\n"))
      raise InvalidMailError, "empty mail" if mail_message.header.empty?
      
      mail_header = mail_message.header
      bts_message = Message.new(@project.report_type)

      # check mail loop
      unless mail_header['X-Kagemai-Loop'].to_s.empty? then
        raise InvalidMailError, "mail loop detected"
      end
      
      from_addr, = RMail::Address.parse(mail_header['from'])
      title = Mail.b_decode(mail_header['subject'].to_s.dup)
      if title.size == 0 then
        title = '(no subject)'
      end

      body = nil
      attachments = []
      if mail_message.multipart? then
        ctime = Time.parsedate(mail_message.header['Date'])
        mail_message.each_part do |part|
          if !body && part.header.content_type == 'text/plain' then
            body = part.decode
          else
            name = part.header.param('Content-Disposition', 'filename')
            if name[0,1] == '"' then
              # parameter may be folding and not support (yet).
              name = name[1..-1]
            end
            if name.nil? || name.size == 0 then
              name = "unnamed_attachment"
            end
            mime_type = part.header.content_type
            file = part.decode
            attachments << [FileElementType::FileInfo.new3(name, mime_type, ctime, file), file]
          end
        end
      else
        body = mail_message.decode
      end

      raise InvalidMailError, "No text body." if body.nil?

      report = get_report(mail_header['in-reply-to'], title)
      if report then
        pmessage = report.last
        @project.report_type.each do |etype|
          next if etype.kind_of?(FileElementType) 
          next unless etype.report_attr
          bts_message[etype.id] = pmessage[etype.id]
        end
      end

      bts_message['email'] = from_addr.address
      bts_message['title'] = strip_subject_tag(kconv(title))
      
      if bts_message.has_element?('cc') then
        cc_addrs = []
        if report then
          report['cc'].split(/[,\s]+/).each{|addr| cc_addrs << addr}
        end
        
        if mail_header['cc'] then
          RMail::Address.parse(mail_header['cc']).each{|a| cc_addrs << a.address}
        end
        
        bts_message['cc'] = cc_addrs.uniq.join(", ")
      end
      
      set_message_body(bts_message, kconv(body))
      bts_message.set_option('email_notification', true)
      store_attachments(bts_message, attachments)
      
      if report then
        @project.add_message(report.id, bts_message)
      else
        report = @project.new_report(bts_message)
      end
      
      # save mail
      @project.save_mail(str, report.id, bts_message.id)
      
      accept_message = "ACCEPT: from <#{from_addr.address}>, "
      accept_message += "project.id = #{@project.id}, report.id = #{report.id}, "
      accept_message += "message.id = #{bts_message.id}"
      log(accept_message)
    end
    
    def kconv(str)
      KKconv.conv(str, KKconv::EUC, KKconv::JIS)      
    end
    
    def get_report(msg_id, title)
      msg_id_obj = MessageID.parse(msg_id)
      if msg_id_obj && msg_id_obj.project_id == @project.id then
        return @project.load_report(Integer(msg_id_obj.report_id))
      end
      
      if /\[#{@project.id}:0*(\d+)\]/ =~ title then
        report_id = Integer($1)
        return @project.load_report(report_id)
      end
      
      nil
    end
    
    def strip_subject_tag(str)
      str.sub(/^(RE)?.*\[#{@project.id}:\d+\]\s*/i, '')
    end
    
    def set_message_body(message, body)
      body = body.collect {|line|
        if Config[:allow_mail_body_command] && /^\#.*KAGEMAI\s*:(.+)/i =~ line then
          id, value = $1.split('=')
          if !id.to_s.empty? && !value.to_s.empty? then
            id.strip!
            value.strip!
            if message.has_element?(id) then
              message[id] = value 
            else
              etype = message.type.find_by_name(id)
              message[etype.id] = value if etype
            end
          end
          line = ''
        end
        line
      }.join
      message['body'] = body
    end
    
    def store_attachments(message, attachments)
      felement = find_file_element_type(message)
      return unless felement
      
      attachments.each do |fileinfo, value|
        file = Tempfile.new('kagemai_tempfile')
        file.binmode
        begin
          file.write(value)
          file.flush
          file.rewind
          
          fileinfo.seq = @project.store_attachment(file, fileinfo)
          felement.add_fileinfo(fileinfo)
        ensure
          file.close
        end
      end
    end
    
    def find_file_element_type(message)
      message.type.each do |etype|
        if etype.kind_of?(FileElementType) then
          return message.element(etype.id)
        end
      end
      nil
    end
  end

end

if $0 == __FILE__
  project_id = ARGV.shift
  if project_id.to_s.empty? || ARGV.size != 0 then
    log("usage: ruby mailif.rb project-id")
    exit(1)
  end
  
  begin
    app = Kagemai::MailApp.new(project_id.dup.untaint, Kagemai::Config[:language])
    app.accept(STDIN)
  rescue Exception => e
    log("#{e.to_s}: #{e.class}\n")
    log(e.backtrace.join("\n"))
  end
end
