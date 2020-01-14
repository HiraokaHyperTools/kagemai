=begin
 MessageBundle - message resource bundle
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
