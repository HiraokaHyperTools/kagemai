=begin
  CacheManager
=end

require 'pstore'
require 'kagemai/logger'

module Kagemai
  class CacheManager
    def initialize(dir)
      @dir = dir
      @filename = "#{@dir}/cache.pstore"
    end
    
    def load_cache(type, key)
      return nil if type == 'none'
      return nil unless File.exist?(@filename)
      
      store = PStore.new(@filename)
      begin
        store.transaction do
          store[type][key]
        end
      rescue TypeError
        # may be "incompatible marshal file format".
        # remove cache file
        File.unlink(@filename)
        nil
      end
    end
    
    def save_cache(type, key, data)
      return if type == 'none'
      
      unless File.exist?(@dir) then
        Dir.mkdir(@dir) 
        FileUtils.chmod2(Config[:dir_mode], @dir)
      end
      
      do_init = !File.exists?(@filename)
      store = PStore.new(@filename)
      if do_init then
        store.transaction do
          store['project'] = {}
          store['report']  = {}
        end
        FileUtils.chmod2(Config[:file_mode], @filename)
      end
      
      store.transaction do
        store[type][key] = data
      end
    end
    
    def invalidate_cache(type, key)
      return nil unless File.exist?(@filename)
      
      begin
        store = PStore.new(@filename)
        store.transaction do
          if type == 'project' then
            store[type] = {}
          else
            store[type].delete(key)
          end
        end
      rescue
        File.unlink(@filename)
      end
    end
    
  end # class CacheManager

end # module Kagemai

