#!/usr/bin/env ruby
=begin
  user.cgi -- KAGEMAI CGI Interface (user mode).
=end

load 'guest.cgi'
execute(Kagemai::Mode::USER)
