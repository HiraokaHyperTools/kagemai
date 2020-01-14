#!/usr/bin/ruby
# usage: ruby migrate_resource.rb resourece_dir

require 'kconv'
require 'fileutils'

def print_usage_and_exit()
  $stderr.puts "usage: ruby migrate_resource.rb resourece_dir"
  exit 1
end

print_usage_and_exit() unless ARGV.size == 1

dir = ARGV.shift
print_usage_and_exit() unless File.exist?(dir) || File.directory?(dir)

def conv(str)
  Kconv::kconv(str, Kconv::UTF8, Kconv::EUC)
end

def convert_file(filename)
  puts "convert " + filename
  FileUtils.copy(filename, filename + '.bak')
  src = File.open(filename, 'r') {|f| f.read}
  File.open(filename, 'w') {|f| f.write(conv(src))}
end

# migrate messages
Dir.glob("#{dir}/**/messages") do |filename|
  convert_file(filename)
end

# migrate *.rhtml, *.rtxt, *.rb
ext = %w(.rhtml .rtxt .rb)
pattern = ext.collect{|e| "#{dir}/**/*#{e}"}.join("\0")
Dir.glob(pattern) do |filename|
  convert_file(filename)
end

# migrate *.xml
def convert_xml_file(filename)
  file = File.open(filename, 'r')
  if file.gets =~ /^<\?xml.*encoding=\"(.*)\"\?>/ then
    return if $1 == 'UTF-8'
    
    puts "convert " + filename
    FileUtils.copy(filename, filename + '.bak')
    str = %Q!<?xml version="1.0" encoding="UTF-8"?>\n!
    str += conv(file.read)
    File.open(filename, 'w'){|f| f.write(str)}
  else
    raise "bad xml format: #{filename}"
  end
end

Dir.glob("#{dir}/**/*.xml") do |filename|
  convert_xml_file(filename)
end
