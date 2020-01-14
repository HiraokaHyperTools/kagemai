=begin
  TemplateCache : cache compiled template
  
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

module Kagemai
  class TemplateCache
    @@cache = {}
    
    def self.open(project, filename, &block)
      mtime = File.mtime(filename)
      
      value = load_mem_cache(filename, mtime)
      return value if value
      
      value = load_file_cache(project, filename, mtime)
      return value if value
      
      value = File.open(filename, "rb") {|file| yield file}
      save_mem_cache(filename, value)
      save_file_cache(project, filename, value)
      
      value
    end
    
    def self.load_mem_cache(filename, mtime)
      value = nil
      if @@cache.has_key?(filename) then
        value, ctime = @@cache[filename]
        value = nil if ctime < mtime
      end
      value
    end
    
    def self.save_mem_cache(filename, value)
      @@cache[filename] = [value, Time.now]
    end
    
    def self.load_file_cache(project, filename, mtime)
      value = nil
      
      if project then
        cfilename = cache_filename(project, filename)
        return nil unless File.exists?(cfilename)
        
        cache_mtime = File.mtime(cfilename)
        if mtime < cache_mtime then
          value = File.open(cfilename) {|file| file.read}
        end
      end
      
      value
    end
    
    def self.save_file_cache(project, filename, value)
      if project then
        cfilename = cache_filename(project, filename)
        File.open(cfilename, "wb") {|file| file.print value}
      end
    end
    
    def self.cache_filename(project, filename)
      project.cache_dir + "/" + File.basename(filename) + ".compile"
    end
    
  end # TemplateCache
end
