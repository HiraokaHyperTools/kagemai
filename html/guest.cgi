#!/usr/bin/env ruby
=begin
  guest.cgi - KAGEMAI CGI main
  Copyright(C) 2002-2008 FUKUOKA Tomoyuki, DAIFUKUYA.
=end

BEGIN { $stdout.binmode }

$KCODE = 'e'
$SAFE = 1

# $DEBUG = 1
$SHOW_ENV_VARS = false # debug
$KAGEMAI_DEBUG = false # debug

work_dir = File.dirname(File.expand_path(__FILE__)).untaint # setup
if File.symlink?(work_dir) then
  work_dir = File.readlink(work_dir)
end

kagemai_root = File.dirname(work_dir.untaint) # setup
config_file  = work_dir + '/kagemai.conf' # setup

$:.unshift(kagemai_root + '/lib')

require 'kagemai/config'

Kagemai::Config.initialize(kagemai_root, config_file)

require 'kagemai/kagemai'
require 'kagemai/mode'
require 'kagemai/kcgi'
require 'kagemai/kconv'
require 'kagemai/util'

if $KAGEMAI_DEBUG then
  ## init Logger for debugging
  require 'kagemai/logger'
  Kagemai::Logger.level = Kagemai::Logger::DEBUG
  Kagemai::Logger.add_category('Temp')
end

def print_maintenance_message()
  print "Content-type: text/plain; charset=iso-8859-1\n\n";
  print "This system is under maintenance now.\n"
  print "Please visit again several hours later.\n"
  print "--\n"
  print "Bug Tracking System KAGEMAI.\n"
end

def execute(mode, cgi = nil)
  kcgi = nil
  begin
    if Kagemai::Config[:maintenance_mode] && mode != Kagemai::Mode::ADMIN then
      print_maintenance_message()
      return
    end
    
    cgi = CGI.new("html4Tr") unless cgi
    kcgi = Kagemai::KCGI.new(cgi)
    app = Kagemai::CGIApplication.new(kcgi, mode)
    
    result = app.action()
    result.respond(kcgi, $KAGEMAI_DEBUG, $SHOW_ENV_VARS)
    
  rescue Kagemai::Error => e
    err_msg = '<p class="error">Following errors occurred.</p>'
    err_msg += "\r\n<pre>#{e.class}: "
    err_msg += "#{Kagemai::KKconv.conv(e.to_s, Kagemai::KKconv::EUC).escape_h}</pre>"
    err_msg += %Q!\r\n<pre>#{e.backtrace.join("\r\n")}</pre>! if $KAGEMAI_DEBUG
    
    print "HTTP/1.1 200 OK\r\n" if defined?(MOD_RUBY)
    print "Content-Type: text/html; charset=EUC-JP\r\n"
    print "Content-Language: ja\r\n"
    print "\r\n"
    print "<HTML>\r\n"
    print "<HEAD>\r\n"
    print "  <META content=text/html; charset=EUC-JP http-equiv=Content-Type>\r\n"
    print "  <META content=text/css http-equiv=Content-Style-Type>\r\n"
    print "  <LINK href=kagemai.css rel=stylesheet type=text/css>\r\n"
    print "  <TITLE>#{e.class.to_s}</TITLE>\r\n"
    print "</HEAD>\r\n"
    print "<BODY>\r\n"
    print err_msg + "\r\n"
    print "</BODY>\r\n"
    print "</HTML>\r\n"
  ensure
    kcgi.close if kcgi
  end
  
rescue Exception => e
  print "HTTP/1.1 200 OK\r\n" if defined?(MOD_RUBY)
  print "Content-Type: text/plain\r\n\r\n"
  print "Following errors occurred. Please contact administrator.\r\n\r\n"
  print "#{e.to_s} (#{e.class})\r\n"
  
  if $KAGEMAI_DEBUG then
    print "\r\n"
    print e.backtrace.join("\r\n") + "\r\n"
    print "-------------------------------\r\n"
    print "Debug Log: \r\n"
    print Kagemai::Logger.buffer()
  else
    $stderr.puts "#{e.to_s} (#{e.class})"
    $stderr.puts e.backtrace.join("\r\n")
  end
end

script_filename = File.basename(ENV.fetch('SCRIPT_FILENAME', $0))
if script_filename == File.basename(__FILE__) then
  execute(Kagemai::Mode::GUEST)
end
