#!/usr/bin/ruby
=begin
  convert_all.rb - convert all project store type.
=end

## usage: ruby convert_all.rb kagemai.conf new-store-type

$kagemai_root = File.expand_path(File.dirname(__FILE__) + "/..") # setup
$:.unshift "#{$kagemai_root}/lib"

module Kagemai
  class AllStoreConverter
    def initialize(bts, store_type)
      @bts = bts
      unless /^Kagemai::/ =~ store_type then
        store_type = 'Kagemai::' + store_type
      end
      @new_db_manager_class = @bts.validate_store(store_type)
      @store_type = store_type
    end
    
    def convert()
      @bts.each_project {|project| convert_project(project) }
    end
    
    def convert_project(project)
      puts "convert #{project.id}"
      @bts.convert_store(project.id, 
                         project.charset,
                         project.report_type,
                         project.db_manager_class, 
                         @new_db_manager_class)
      project.save_config({'store' => @store_type})
    end
  end
end

if $0 == __FILE__ then
  unless ARGV.size == 2 then
    puts "usage: ruby convert.rb project-id new-store-type"
    exit 1
  end
  
  config_file = ARGV.shift
  store_type  = ARGV.shift
  
  require 'kagemai/config'
  Kagemai::Config.initialize($kagemai_root, config_file)
  
  require 'kagemai/message_bundle'
  Kagemai::MessageBundle.open(Kagemai::Config[:resource_dir], 
                              Kagemai::Config[:language], 
                              Kagemai::Config[:message_bundle_name])
  
  require 'kagemai/bts'
  bts = Kagemai::BTS.new(Kagemai::Config[:project_dir])
  Kagemai::AllStoreConverter.new(bts, store_type).convert()
end
