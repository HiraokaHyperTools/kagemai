#!/usr/bin/ruby -w
=begin
 Make file set for distribution.
=end

require 'fileutils'

if ARGV.size != 1
  puts "usage: ruby make_dist directory"
  exit 1
end
dist_path = ARGV.shift

def copy(from, to)
  FileUtils.copy(from, to)
  stat = File.stat(from)
  File.chmod(stat.mode, to)
  File.utime(stat.atime, stat.mtime, to)
end

files = ['MANIFEST']
IO.foreach('MANIFEST') do |line|
  line.strip!
  next if line.empty?
  next if /\[.+\]/ =~ line
  files << line
end

FileUtils.mkpath dist_path unless test(?e, dist_path)
files.each do |filename|
  dist_dir = dist_path + '/' + File.dirname(filename)
  FileUtils.mkpath dist_dir unless test(?e, dist_dir)
  distname = dist_path + '/' + filename
  puts "#{filename} => #{distname}"
  copy(filename, distname)
end
