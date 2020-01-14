=begin
  ChaptcaHandler : helpr for captcha
=end

require 'kagemai/config'
require 'kagemai/mode'

module Kagemai
  module CaptchaHandler
    CAPTCHA_CODE_KEY = 'captcha_code'
    CAPTCHA_IMAGE_KEY = 'captcha_code_image'
    CAPTCHA_SKIP_KEY = 'captcha_skip'
    
    def use_captcha?()
      Config[:captcha_char_length] > 0 && @mode == Mode::GUEST
    end
        
    def create_image()
      require 'noisyimage'
      NoisyImage.new(Config[:captcha_char_length], Config[:captcha_font], @lang)
    end
    
    def init_captcha()
      if use_captcha?() then
        image = create_image()
        @session[CAPTCHA_CODE_KEY] = image.code
        @session[CAPTCHA_IMAGE_KEY] = image.code_image
      end
    end
    
    def get_captcha_image()
      image = @session[CAPTCHA_IMAGE_KEY]
      raise SecurityError, 'no captcha image' unless image
      @session[CAPTCHA_IMAGE_KEY] = nil
      image
    end
    
    def check_captcha()
      return true unless use_captcha?
      
      if @session[CAPTCHA_SKIP_KEY] == 'true' then
        @session[CAPTCHA_SKIP_KEY] = nil
        return true
      end
      
      code = @session[CAPTCHA_CODE_KEY]
      @session[CAPTCHA_CODE_KEY] = nil
      @session[CAPTCHA_IMAGE_KEY] = nil
      
      code && code == @cgi.get_param(CAPTCHA_CODE_KEY)
    end
    
    def skip_captcha()
      @session[CAPTCHA_SKIP_KEY] = 'true'
      @session[CAPTCHA_CODE_KEY] = nil
      @session[CAPTCHA_IMAGE_KEY] = nil
    end
  end
end
