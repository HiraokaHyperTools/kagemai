=begin
  mail/mailer.rb

  Copyright(C) 2002, 2003 FUKUOKA Tomoyuki.

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

  $Id: mailer.rb 10 2004-07-06 11:44:32Z fukuoka $
=end

require 'net/smtp'
require 'kagemai/config'

module Kagemai
  class Mailer
    @@mailer = nil
    
    def self.set_mailer(mailer)
      @@mailer = mailer
    end
    
    def self.sendmail(mail, from_addr, *to_addrs)
      to_addrs = to_addrs.collect{|addr| addr.dup.untaint}
      to_addrs.uniq!
      @@mailer.sendmail(mail, from_addr, *to_addrs) if @@mailer
    end
  end
  
  class SmtpMailer
    def initialize(server = Config[:smtp_server], port = Config[:smtp_port])
      @server = server
      @port = port
    end
    
    def sendmail(mail, from_addr, *to_addrs)
      Net::SMTP.start(@server, @port) do |smtp|
        smtp.send_mail(mail.to_s, from_addr, *to_addrs)
      end
    end
  end
  
  class MailCommandMailer
    def initialize(command = Config[:mail_command])
      @mail_command = command
    end
    
    def sendmail(mail, from_addr, *to_addrs)
      to_addrs.each {|to| sendmail_by_command(mail, to)}
    end
    
    def sendmail_by_command(mail, to)
      subject = mail.subject.gsub(/\n/, ' ')
      
      pipe_pr, pipe_cw = IO.pipe
      pipe_cr, pipe_pw = IO.pipe
      
      fork {
        pipe_pr.close
        pipe_pw.close
        STDIN.reopen(pipe_cr)
        STDOUT.reopen(pipe_cw)
        STDERR.reopen(pipe_cw)
        
        exec(@mail_command.untaint, '-s', subject.untaint, to.dup.untaint)
      }
      
      pipe_cw.close
      pipe_cr.close
      
      pipe_pw.write(mail.body)
      pipe_pw.close()
      
      errors = pipe_pr.read()
      unless errors.to_s.empty? then
        raise errors
      end
      
      Process.wait
      pipe_pr.close
    end
    
  end
  
  class SendmailCommandMailer
    def initialize(command = Config[:mail_command])
      @mail_command = command
    end
    
    def sendmail(mail, from_addr, *to_addrs)
      to_addrs.each {|to| sendmail_by_command(mail, from_addr, to)}
    end
    
    def sendmail_by_command(mail, from_addr, to)
      pipe_pr, pipe_cw = IO.pipe
      pipe_cr, pipe_pw = IO.pipe
      
      fork {
        pipe_pr.close
        pipe_pw.close
        STDIN.reopen(pipe_cr)
        STDOUT.reopen(pipe_cw)
        STDERR.reopen(pipe_cw)
        
        exec(@mail_command.untaint, "-f#{from_addr}", to.dup.untaint)
      }
      
      pipe_cw.close
      pipe_cr.close
      
      pipe_pw.write("#{mail.header}\n#{mail.body}")
      pipe_pw.close()
      
      errors = pipe_pr.read()
      unless errors.to_s.empty? then
        raise errors
      end
      
      Process.wait
      pipe_pr.close
    end
  end

end
