=begin
 MessageBundle - message resource bundle

  Copyright(C) 2002-2004 FUKUOKA Tomoyuki.

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
=end

require 'kagemai/error'

module Kagemai
  class MessageBundle
    def self.open(base_dir, lang, filename, use_cache = true)
      Thread.current[:MessageBundle] = MessageBundle.new("#{base_dir}/#{lang}/#{filename}", lang, use_cache)
    end
    
    def self.update(filename)
      File.open(filename, 'rb') do |file|
        Thread.current[:MessageBundle].update(file)
      end
    end
    
    def self.[](key)
      Thread.current[:MessageBundle][key]
    end

    def self.has_key?(key)
      Thread.current[:MessageBundle].has_key?(key)
    end
    
    def initialize(filename, lang, use_cache)
      @messages = {}
      
      cache_name = "#{Config[:tmp_dir]}/messages.#{lang}.cache"
      if use_cache && File.exist?(cache_name) then
        if File.mtime(filename) < File.mtime(cache_name) then
          begin
            File.open(cache_name, 'rb') {|cache| @messages = Marshal.load(cache)}
            return
          rescue
            # ignore, try load original file
          end
        end
      end
      
      File.open(filename, 'rb') {|file| load_messages(file)}
      
      if use_cache then
        File.open(cache_name, 'wb') {|cache| Marshal.dump(@messages, cache)}
        FileUtils.chmod2(Config[:file_mode], cache_name)
      end
    end

    def update(file)
      load_messages(file)
    end

    def load_messages(file)
      file.each do |line|
        line = line.sub(/#.*/, '').strip()
        next if line.empty?
        
        key, *message = line.split(/=/)
        key = key.to_s.strip.untaint
        message = message.join('=').to_s.strip
        next if (key.empty? || message.empty?)

        @messages[key.untaint.intern] = message
      end
    end

    def [](key)
      unless @messages.has_key?(key) then
        raise NoSuchResourceError, "No message resource for '#{key.inspect}'"
      end
      @messages[key]
    end

    def has_key?(key)
      @messages.has_key?(key)
    end
  end
end
