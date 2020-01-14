=begin
  PMutex - プロセス/スレッド間での排他制御を提供します。

  Copyright(C) 2002-2004 FUKUOKA Tomoyuki.

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
