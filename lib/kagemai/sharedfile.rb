=begin
  SharedFile - プロセス/スレッド間で共有して使用する
               ファイルのための排他制御を提供します。

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

  $Id: sharedfile.rb 245 2008-02-05 15:56:07Z fukuoka $
=end

require 'thread'
require 'sync'
require 'kagemai/util'

module Kagemai

  module SharedFile
    @@mutex = Mutex.new
    @@sync = Hash.new

    def self.sync(filename, mode)
      sync_m = nil
      @@mutex.synchronize {
        unless @@sync.has_key?(filename) then
          @@sync[filename] = [0, Sync.new]
        end
        @@sync[filename][0] += 1
        sync_m = @@sync[filename][1]
      }
        
      sync_m.synchronize(mode) {
        yield
      }
    ensure
      @@mutex.synchronize {
        @@sync[filename][0] -= 1
        if @@sync[filename][0] == 0 then
          @@sync.delete(filename)
        end
      }
    end

    def self.read_open(filename)
      sync(filename, Sync::SH) {
        File.open(filename, 'rb') do |file|
          file.flock(File::LOCK_SH)
          yield file
        end
      }
    end

    def self.write_open(filename, readable = false, backup = true)
      sync(filename, Sync::EX) {
        exists = File.exists?(filename)
        File.open(filename, File::RDWR | File::CREAT) do |file|
          file.binmode
          file.flock(File::LOCK_EX)

          if exists && backup then
            backup_filename = filename + '~'
            File.open(backup_filename, 'wb') do |backup|
              backup.write(file.read)
            end
            FileUtils.chmod2(file.stat.mode, backup_filename)
          end

          file.truncate(0) unless readable
          file.rewind()

          yield file

          file.flush()
        end
      }
    end

  end

end

