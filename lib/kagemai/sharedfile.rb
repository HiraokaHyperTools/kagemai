=begin
  SharedFile - プロセス/スレッド間で共有して使用する
               ファイルのための排他制御を提供します。
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

