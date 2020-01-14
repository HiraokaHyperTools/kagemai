#!/usr/bin/ruby
=begin
  guest.fcgi - KAGEMAI FastCGI interface
=end

begin
  require 'rubygems'
rescue LoadError
end
require 'fcgi'
load 'guest.cgi'

work_dir     = File.dirname(File.expand_path(__FILE__)).untaint # setup
kagemai_root = File.dirname(work_dir.untaint) # setup
config_file  = work_dir + '/kagemai.conf' # setup

FCGI.each_cgi {|cgi|
  Kagemai::Config.initialize(kagemai_root, config_file)
  execute(Kagemai::Mode::GUEST, cgi)
}
