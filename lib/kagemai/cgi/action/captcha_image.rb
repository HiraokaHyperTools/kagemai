=begin
  CaptchaImage : Download captcha image
=end

require 'kagemai/util'
require 'kagemai/error'
require 'kagemai/cgi/action'
require 'kagemai/cgi/captcha'

module Kagemai  
  class CaptchaImage < Action
    include CaptchaHandler
    
    def execute()
      begin
        @session = @cgi.create_session()
      rescue ArgumentError 
        unless $KAGEMAI_DEBUG then
          raise SecurityError, 'no captcha image'
        else
          # for test
          @session = @cgi.create_session('session_id' => @cgi.get_param('sid'))
          raise ParameterError unless @session
        end
      end
      
      image = get_captcha_image()
      CaptchaImageResult.new(image)
    end
    
    def self.name()
      'captcha'
    end
    Action::add_action(self)
  end
  
  class CaptchaImageResult
    def initialize(image)
      @image = image
    end

    def respond(cgi, flush_log, show_env, out = $stdout)
      $stdout.print http_header(cgi, @image.size)
      http_body_with_print(cgi, flush_log, show_env, out)
    end

    def http_header(cgi, length)
      if defined?(MOD_RUBY) then
        Apache::request.headers_out.clear
      end
      
      opts = {
        'status'  => 'OK',
        'type'    => 'image/jpeg',
        'length'  => length,
        'Pragma'  => 'no-cache',
        'Expires' => Time.now,
        'Cache-Control' => 'no-cache'
      }
      
      cgi.header(opts)
    end
      
    def http_body_with_print(cgi, flush_log, show_env, out = $stdout)
      print @image
    end
    
  end
end
