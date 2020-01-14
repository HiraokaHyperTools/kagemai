=begin
  mail/mailer.rb
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
