=begin
  util.rb - utilities
=end

require 'fileutils'
require 'erb'
require 'cgi'
require 'thread'
require 'date'
require 'kagemai/error'
require 'kagemai/logger'
require 'kagemai/template_cache'

class String
  def quote(prefix = '> ')
    return prefix + self.gsub(/\n/m, "\n#{prefix}");
  end

  def escape_h()
    CGI::escapeHTML(self)
  end

  def unescape_h()
    CGI::unescapeHTML(self)
  end

  def escape_u()
    CGI::escape(self)
  end

  def unescape_u()
    CGI::unescape(self)
  end
end

if RUBY_VERSION < "1.9.0"
  require 'parsedate' 
else
  require 'time'
  require 'date/format'
  module ParseDate
    def ParseDate.parsedate(date, cyear)
      h = Date._parse(date)
      [h[:year], h[:mon], h[:mday], h[:hour], h[:min], h[:sec], [:zone], [:wday]]
    end
  end
end

class Time
  @@week_of_days = nil
  
  def self.parsedate(date, cyear = false)
    ary = ParseDate.parsedate(date, cyear)
    
    if ary.size >= 6 && ary[6] == 'GMT' then
      Time::gm(*ary[0..-3])
    else
      Time::local(*ary[0..-3])
    end
  end
  
  def format()
    self.strftime("%Y-%m-%d %H:%M:%S")
  end
  
  def format_date(lang = 'ja')
    self.strftime("%Y/%m/%d (#{Time.week_of_day(self.wday)})")
  end  
  
  def self.week_of_day(wod)
    @@week_of_days ||= [
      Kagemai::MessageBundle[:wod_sun], Kagemai::MessageBundle[:wod_mon], 
      Kagemai::MessageBundle[:wod_tue], Kagemai::MessageBundle[:wod_wed], 
      Kagemai::MessageBundle[:wod_thu], Kagemai::MessageBundle[:wod_fri], 
      Kagemai::MessageBundle[:wod_sat], 
    ]
    @@week_of_days[wod]
  end
end

class Date
  # for save xml
  def escape_h()
    self.to_s.escape_h()
  end
  
  def week_of_day()
    Date.week_of_day(self.cwday)
  end
  
  def self.week_of_day(wd)
    Time.week_of_day(wd)
  end
end


def File.create(path)
  File.open(path, 'wb') {|file| }
end

module FileUtils
  def FileUtils.chmod2(mode, *filenames)
    begin
      chmod_files = filenames.find_all{|name| (File.stat(name).mode & 07777) != (mode & 07777)}
      FileUtils.chmod(mode, *chmod_files) if chmod_files.size > 0
    rescue SystemCallError => e
      prefix = 'kagemai: '
      bt = e.backtrace.join("\n" + prefix + '  ')
      STDERR.puts "#{prefix} #{e} (#{e.class})"
      STDERR.puts "#{prefix} #{bt}"
    end
  end
end

def Dir.delete_dir(dir)
  Dir.foreach(dir) do |path|
    next if path == '.' || path == '..'
    path = dir + '/' + path
    path.untaint
    if FileTest.directory?(path)
      Dir.delete_dir(path)
    else
      File.unlink(path)
    end
  end
  Dir.rmdir(dir)
end

module Kagemai
  module Util    
    def Util.safe(level = 4)
      result = nil
      Thread.start {
        $SAFE = level
        result = yield
      }.join
      result
    end
    
    def Util.erb_eval_file(filename, binding = TOPLEVEL_BINDING)
      src = TemplateCache::open(Thread.current[:Project], filename) {|file|
        ERB.new(file.read.gsub(/\r\n/, "\n")).src
      }
      eval(src.untaint, binding, filename)
    end
    
    def Util.eval_template(filename, template_dir, lang, b = TOPLEVEL_BINDING)
      dirs = ["#{Config[:resource_dir]}/#{lang}/template/#{Config[:default_template_dir]}"]
      dirs.unshift(template_dir) if template_dir
      dirs.each do |dir|
        path = dir + '/' + filename
        if File.exist?(path)
          return erb_eval_file(path, b)
        end
      end
      raise NoSuchTempalteError, "template file not found: '#{filename}'"
    end
    
    def Util.untaint_path(path)
      if path.include?('../')
        raise SecurityError, "Insecure path - '#{path}'"
      end
      path.untaint
    end

    def Util.untaint_digit_id(id)
      raise ParameterError, "Invalid ID - #{id.inspect}" unless id =~ /\A\d+\Z/
      id.untaint
    end
  end
end
