#!/usr/bin/ruby -wKu

BEGIN { 
  $stdout.binmode
}

require 'test/unit'
begin
  require 'rubygems'
rescue LoadError
end

$SAFE = 1

$WIN32 = (RUBY_PLATFORM =~ /mswin32|cygwin/) != nil
$:.unshift "./lib"

kagemai_root = "."

require 'kagemai/config'
Kagemai::Config.initialize(kagemai_root, nil)
require 'kagemai/kcgi' # for use Config['tmp_dir']

if File.exist?("test.conf") then
  puts "load test.conf"
  eval(File.open("test.conf").read.untaint)
end

require 'kagemai/logger'
if $DEBUG then
  Kagemai::Logger.level = Kagemai::Logger::DEBUG

  #Kagemai::Logger.add_category('Project')
  #Kagemai::Logger.add_category('ReportType')
  Kagemai::Logger.add_category('DBI')
  Kagemai::Logger.add_category('Temp')
end

Test::Unit::AutoRunner.run(true, 'test/', ['--pattern=[A-z]*_test.rb', '--exclude=^\.svn'] + ARGV)

if $DEBUG then
  puts Kagemai::Logger.buffer()
end
