=begin
  SeqFile - persistent sequence number file
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
