#!/usr/bin/ruby
# usage: ruby clean_cache.rb project_dir

TARGET_EXT  = ['.cache', '.compile', '.pstore']
TARGET_FILE = ['cache1', 'cache2']

def print_usage_and_exit()
  $stderr.puts "usage: ruby clean_cache.rb project_dir"
  exit 1
end

print_usage_and_exit() unless ARGV.size == 1

dir = ARGV.shift
print_usage_and_exit() unless File.exist?(dir) || File.directory?(dir)

patterns = TARGET_EXT.collect{|ext| "#{dir}/**/*#{ext}"}
patterns += TARGET_FILE.collect{|file| "#{dir}/**/#{file}"}

require 'fileutils'
Dir.glob(patterns.join("\0")) do |file| 
  puts "remove " + file
  File.unlink(file)
end
