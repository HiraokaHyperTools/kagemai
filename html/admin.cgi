#!/usr/bin/env ruby
=begin
  admin.cgi -- KAGEMAI CGI Interface (administrator mode).
=end

load 'guest.cgi'
execute(Kagemai::Mode::ADMIN)
