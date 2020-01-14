=begin
  ChaptcaHandler : helpr for captcha
  
  Copyright(C) 2008 FUKUOKA Tomoyuki.
  
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

require 'kagemai/config'
require 'kagemai/mode'

module Kagemai
  module CaptchaHandler
    CAPTCHA_CODE_KEY = 'captcha_code'
    CAPTCHA_IMAGE_KEY = 'captcha_code_image'
    
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
      
      code = @session[CAPTCHA_CODE_KEY]
      @session[CAPTCHA_CODE_KEY] = nil
      @session[CAPTCHA_IMAGE_KEY] = nil
      
      code && code == @cgi.get_param(CAPTCHA_CODE_KEY)
    end
    
  end
end
