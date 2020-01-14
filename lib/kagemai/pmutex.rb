=begin
  PMutex - mutex for multi processes and threads
=end

require 'thread'
require 'sync'

module Kagemai

  class PMutex
    SH = Sync::SH
    EX = Sync::EX
    
    @@sync  = Sync.new  # for mulit-thread lock
    @@lockfile = nil    # for multi-process lock
    @@level    = 0      # lock level in same thread
    
    def initialize(lockfile)
      @lockfilename = lockfile
    end
    
    def open_mode(mode)
      r = (mode == SH ? 'rb' : 'wb')
      r
    end
    
    def flock_mode(mode)
      r = (mode == SH ? File::LOCK_SH : File::LOCK_EX)
      r
    end
    def lock(mode = EX)
      @@sync.lock(mode)
      if @@level == 0 then
        @@lockfile = File.open(@lockfilename, open_mode(mode))
        @@lockfile.flock(flock_mode(mode))
      end
      @@level += 1
    end
    
    def unlock(mode = EX)
      @@level -= 1
      if @@level == 0 then
        @@lockfile.flock(File::LOCK_UN)
        @@lockfile.close()
        @@lockfile = nil
      end
      @@sync.unlock(mode)
    end
    
    def synchronize(mode = EX)
      begin
        lock(mode)
        yield
      ensure
        unlock(mode)
      end
    end

  end

end
