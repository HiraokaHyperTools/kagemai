=begin
  Mode - 管理者、ユーザ、ゲストなどのモード

  Copyright(C) 2002, 2003 FUKUOKA Tomoyuki.

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

  $Id: mode.rb 10 2004-07-06 11:44:32Z fukuoka $
=end

module Kagemai
  class Mode
    def initialize(name, url)
      @name = name
      @url = url
    end
    
    def href(params = '')
      unless current? then
        params = '?' + params unless params.empty?
        MessageBundle[@name.intern].href(@url + params)
      else
        nil
      end
    end
    attr_reader :name, :url

    def current?
      self == CGIApplication.instance.mode
    end

    GUEST = Mode.new('mode_guest', Config[:guest_mode_cgi])
    USER  = Mode.new('mode_user',  Config[:user_mode_cgi])
    ADMIN = Mode.new('mode_admin', Config[:admin_mode_cgi])
  end
end
