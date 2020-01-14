#!/usr/bin/ruby -w

=begin
  convert.rb - convert store type.

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

  $Id: convert.rb 10 2004-07-06 11:44:32Z fukuoka $
=end

## usage: ruby convert.rb project-id new-store-type

kagemai_root = File.dirname(File.dirname(File.expand_path(__FILE__))) # setup
config_file  = "#{kagemai_root}/kagemai.conf" # setup

$: << "#{kagemai_root}/lib"
require 'kagemai/config'

Kagemai::Config.initialize(kagemai_root, config_file)

require 'kagemai/bts'
require 'kagemai/project'
require 'kagemai/message_bundle'

module Kagemai

  def self.convert_store_type(project_id, store_type)
    MessageBundle.open(Config[:resource_dir], 
                       Config[:language], 
                       Config[:message_bundle_name])

    bts = BTS.new(Config[:project_dir])
    project = bts.open_project(project_id)

    new_db_manager_class = bts.validate_store(store_type)

    bts.convert_store(project.id, 
                      project.charset,
                      project.report_type,
                      project.db_manager_class, 
                      new_db_manager_class)

    project.save_config({'store' => store_type})
  end

end

if $0 == __FILE__ then
  unless ARGV.size == 2 then
    puts "usage: ruby convert.rb project-id new-store-type"
    exit 1
  end

  project_id = ARGV.shift
  store_type = ARGV.shift

  Kagemai::convert_store_type(project_id, store_type)
end
