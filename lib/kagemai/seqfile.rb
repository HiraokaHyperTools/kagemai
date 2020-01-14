=begin
  SeqFile - persistent sequence number file

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

  $Id: seqfile.rb 10 2004-07-06 11:44:32Z fukuoka $
=end

module Kagemai
  class SeqFile
    def SeqFile.open(filename)
      seqfile = SeqFile.new(File.open(filename, File::RDWR | File::CREAT))
      if block_given?
        begin
          yield seqfile
        ensure
          seqfile.close
        end
      else
        seqfile
      end
    end
    
    def initialize(port)
      @port = port
      line = port.gets
      @next = line.to_s.empty? ? 1 : line.to_i
    end

    def current()
      @next - 1
    end

    def next()
      result = @next
      @next += 1
      @port.truncate(0)
      @port.rewind
      @port.print(@next.to_s)
      result
    end

    def close()
      @port.close()
    end
  end
end
