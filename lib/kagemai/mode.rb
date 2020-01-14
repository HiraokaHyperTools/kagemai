=begin
  Mode - mode of access
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
