=begin
  CacheManager

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
      
      store = PStore.new(@filename)
      store.transaction do
        if type == 'project' then
          store[type] = {}
        else
          store[type].delete(key)
        end
      end
    end

  end # class CacheManager

end # module Kagemai

