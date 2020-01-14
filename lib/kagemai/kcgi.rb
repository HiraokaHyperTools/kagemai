require 'cgi'
require 'cgi/session'
require 'tempfile'
require 'kagemai/config'

class Tempfile
  alias init_org initialize
  def initialize(basename, tmpdir = nil)
    unless tmpdir
      dir = Kagemai::Config[:tmp_dir]
      if File.directory?(dir) and File.writable?(dir)
        tmpdir = dir
      else
        tmpdir = Dir::tmpdir
      end
    end
    init_org(basename, tmpdir)
  end
end

module Kagemai
  class KCGI
    def initialize(cgi, lang = Config[:language], charset = Config[:charset])
      @cgi = cgi
      
      init_multipart()            
      @lang = get_param('lang', lang)
      @charset = get_param('charset', charset)
      @cached_attachments = {}
      @output_cookies = []
      @session = nil
    end
    attr_reader :lang, :charset, :session
    attr_accessor :cached_attachments
    
    def create_session(opt = {})
      session_param = {
        'prefix' => 'kagemai_',
        'tmpdir' => Config[:tmp_dir],
      }
      session_param.update(opt)
      
      if @cgi.cookies['_session_id'] then
        session_param['session_id'] = @cgi.cookies['_session_id'][0]
      end
      
      @session = CGI::Session.new(@cgi, session_param)
      @session
    end
    
    def close()
      @session.close if @session
    end
    
    def session_gc()
      expire = Time.now - (60 * Config[:session_expire])
      begin
        Dir.glob(Config[:tmp_dir] + '/kagemai_*') do |name|
          File.unlink(name) if File.mtime(name.untaint) < expire
        end
      rescue => e
        $stderr.puts "Kagemai::KCGI#session_gc: " + e.to_s
      end
    end
    
    def method_missing(m, *args, &block)
      unless @cgi.respond_to?(m)
        $stderr.puts "KCGI: cannot respond to #{m}"
        raise "KCGI: cannot respond to #{m}"
      end
      @cgi.send(m, *args, &block)
    end
    
    def env_table
      @cgi.respond_to?(:env_table) ? @cgi.env_table : ENV
    end
    
    def cookies() @cgi.cookies() end
    
    def element(name, opt = nil)
      opt_str = opt ? ' ' + opt.collect{|k, v| %Q!#{k}="#{v}"!}.join(' ') : ''
      unless block_given?
        "<#{name}#{opt_str}>"
      else
        "<#{name}#{opt_str}>"+ yield + "</#{name}>"
      end
    end
    
    def meta(opt) element('meta', opt) end
    def link(opt) element('link', opt) end
    def title(&block) element('title', nil, &block) end
    def body(&block) element('body', nil, &block)  end
    def html(opt = {}, &block) element('html', opt, &block) end
    def head(&block) element('head', nil, &block) end
    
    def header(opt)
      if @session then
        session_cookie = CGI::Cookie::new('_session_id', @session.session_id)
        session_cookie.path = cookie_path()
        session_cookie.expires = Time.now + (60 * Config[:session_expire])
        @output_cookies << session_cookie
        @session.close
      end
      
      opt['cookie'] = @output_cookies unless @output_cookies.empty?
      
      if @cgi.respond_to?(:header)
        @cgi.header(opt)
      else
        # FastCGI
        cgi_headler(opt)
      end
    end
    
    def add_cookie(name, value)
      return if value.to_s.empty?
      
      cookie = CGI::Cookie::new(name, value.escape_u);
      cookie.path = cookie_path()
      cookie.expires = Time.new + (60 * 60 * 24) * 90 # 90 days
      
      @output_cookies << cookie
    end
    
    def delete_cookie(name, value)
      cookie = CGI::Cookie::new(name, '');
      cookie.path = cookie_path()
      cookie.expires = Time.new - (60 * 60 * 24) # yesterday
      
      @output_cookies << cookie
    end
    
    def cookie_path()
      dirname = File.dirname(@cgi.script_name)
      dirname == '/' ? dirname : dirname + '/'
    end
    
    def init_multipart()
      if @cgi.request_method == 'POST' then
        @multipart = (/\Amultipart\/form-data/ =~ @cgi.content_type) != nil
      else
        @multipart = false
      end
      
      if @multipart then
        @params_r = Hash.new
        def self.do_get_param(key)
          unless @params_r.has_key?(key) then
            @params_r[key] = ''
            if @cgi.params[key].size > 0 then
              @params_r[key] = @cgi.params[key].collect{|p| p.read}.join(",\n")
            end
          end
          @params_r[key]
        end
        def self.set_param(key, value)
          @params_r[key] = value
        end
      else
        def self.do_get_param(key)
          @cgi.params[key].join(",\n")
        end
        def self.set_param(key, value)
          @cgi.params[key] = [value]
        end
      end
    end    
    
    def each()
      @cgi.params.each_key do |key|
        yield key, get_param(key)
      end
    end
    
    def params()
      @multipart ? @params_r : @cgi.params
    end
    
    def get_param(key, default = nil)
      v = do_get_param(key).to_s.strip
      v.empty? ? default : v.gsub(/\r\n/m, "\n").gsub(/\r/m, "\n")
    end
    
    def get_attachment(id)
      io = @cgi.params[id][0]
      
      if (defined? StringIO) && io.kind_of?(StringIO) then
        return nil if io.size == 0
        
        file = Tempfile.new("attachment", Config[:tmp_dir])
        
        file.binmode
        file.print io.string
        file.rewind
        
        def file.sio=(sio)
          @sio = sio
        end
          
        def file.original_filename()
          @sio.original_filename()
        end
          
        def file.local_path()
          path()
        end
          
        def file.content_type()
          @sio.content_type()
        end
        
        file.sio = io
        io = file
      end
        
      (io && io.stat.size > 0) ? io : nil
    end
    
    alias :attr :get_param
    alias :fetch :get_param
    
    def mobile_agent?()
      m_agents = [
        'DoCoMo', 'J-PHONE', 'UP\.Browser', 'DDIPOCKET',
        'ASTEL', 'PDXGW', 'Palmscape', 'Xiino',
        'sharp pda browser', 'Windows CE', 'L-mode'
      ]
      self.user_agent =~ /(#{m_agents.join('|')})/i
    end
    
    def ua_ie?()
      self.user_agent =~ /(compatible; MSIE)|(Sleipnir)/
    end
    
    def ua_firefox?()
      self.user_agent =~ /Firefox/
    end
    
    def ua_mozilla?()
      !ua_ie? && !ua_firefox? && self.user_agent =~ /Mozilla\/5.0/
    end
    
    # copy from Ruby's cgi.rb
    def cgi_header(options = "text/html")
      buf = ""
      
      case options
      when String
        options = { "type" => options }
      when Hash
        options = options.dup
      end
      
      unless options.has_key?("type")
        options["type"] = "text/html"
      end
      
      if options.has_key?("charset")
        options["type"] += "; charset=" + options.delete("charset")
      end
      
      if options.delete("nph") or
          (/IIS\/(\d+)/n.match(@cgi.env_table['SERVER_SOFTWARE']) and $1.to_i < 5)
        buf += (@cgi.env_table["SERVER_PROTOCOL"] or "HTTP/1.0")  + " " +
          (CGI::HTTP_STATUS[options["status"]] or options["status"] or "200 OK") +
          CGI::EOL +
          "Date: " + CGI::rfc1123_date(Time.now) + CGI::EOL
        
        unless options.has_key?("server")
          options["server"] = (@cgi.env_table['SERVER_SOFTWARE'] or "")
        end
        
        unless options.has_key?("connection")
          options["connection"] = "close"
        end
        
        options.delete("status")
      end
      
      if options.has_key?("status")
        buf += "Status: " +
          (CGI::HTTP_STATUS[options["status"]] or options["status"]) + CGI::EOL
        options.delete("status")
      end
      
      if options.has_key?("server")
        buf += "Server: " + options.delete("server") + CGI::EOL
      end
      
      if options.has_key?("connection")
        buf += "Connection: " + options.delete("connection") + CGI::EOL
      end
      
      buf += "Content-Type: " + options.delete("type") + CGI::EOL
      
      if options.has_key?("length")
        buf += "Content-Length: " + options.delete("length").to_s + CGI::EOL
      end
      
      if options.has_key?("language")
        buf += "Content-Language: " + options.delete("language") + CGI::EOL
      end
      
      if options.has_key?("expires")
        buf += "Expires: " + CGI::rfc1123_date( options.delete("expires") ) + CGI::EOL
      end
      
      if options.has_key?("cookie")
        if options["cookie"].kind_of?(String) or
            options["cookie"].kind_of?(Cookie)
          buf += "Set-Cookie: " + options.delete("cookie").to_s + CGI::EOL
        elsif options["cookie"].kind_of?(Array)
          options.delete("cookie").each{|cookie|
            buf += "Set-Cookie: " + cookie.to_s + CGI::EOL
          }
        elsif options["cookie"].kind_of?(Hash)
          options.delete("cookie").each_value{|cookie|
            buf += "Set-Cookie: " + cookie.to_s + CGI::EOL
          }
        end
      end
      
      options.each{|key, value|
        buf += key + ": " + value.to_s + CGI::EOL
      }
      
      buf + CGI::EOL
    end # header()

  end
end
