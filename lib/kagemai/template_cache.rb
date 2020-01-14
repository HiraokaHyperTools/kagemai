=begin
  TemplateCache : cache compiled template
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
