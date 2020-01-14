#!/usr/bin/ruby
# usage: ruby migrate09.rb project_dir

require 'kconv'
require 'fileutils'

def print_usage_and_exit()
  $stderr.puts "usage: ruby migrate09.rb project_dir"
  exit 1
end

print_usage_and_exit() unless ARGV.size == 1

dir = ARGV[0]
print_usage_and_exit() unless File.exist?(dir) || File.directory?(dir)

def conv(str)
  Kconv::kconv(str, Kconv::UTF8, Kconv::EUC)
end

def convert_file(filename)
  unless File.exist?(filename + '.bak') then
    puts "convert " + filename
    FileUtils.copy(filename, filename + '.bak')
    src = File.open(filename, 'r') {|f| f.read}
    File.open(filename, 'w') {|f| f.write(conv(src))}
  else
    puts "skip " + filename + " : already exist backup file"
  end
end

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

def convert_config_file(filename)
  unless File.exist?(filename + '.bak') then
    puts "convert " + filename
    FileUtils.copy(filename, filename + '.bak')
    src = File.open(filename, 'r') {|f| f.read}
    
    File.open(filename, 'w') do |f| 
      src.each do |line|
        case line
        when /^@name = (\".*\")$/
          name = conv(eval($1))
          f.puts %Q!@name = #{name.dump}!
        when /^@description = (\".*\")$/
          desc = conv(eval($1))
          f.puts %Q!@description = #{desc.dump}!
        when /^@charset = \"EUC-JP\"$/
          f.puts %Q!@charset = "UTF-8"!
        else
          f.write(line)
        end
      end
    end
  else
    puts "skip " + filename + " : already exist backup file"
  end
end

#####################################################
puts "start migration"

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
Dir.glob("#{dir}/**/*.xml") do |filename|
  convert_xml_file(filename)
end

# migrate config
Dir.glob("#{dir}/**/config") do |filename|
  convert_config_file(filename)
end

# clear cache
target_ext  = ['.cache', '.compile', '.pstore']
target_file = ['cache1', 'cache2']
patterns = target_ext.collect{|ext| "#{dir}/**/*#{ext}"}
patterns += target_file.collect{|file| "#{dir}/**/#{file}"}
Dir.glob(patterns.join("\0")) do |file| 
  puts "remove " + file
  File.unlink(file)
end

puts "done."
