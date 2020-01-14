=begin
  AttachmentHandler - handling form attachment file
=end

require 'kagemai/error'
require 'kagemai/elementtype'
require 'kagemai/mime_type'

module Kagemai
  Attachment = Struct.new(:tempfile, :fileinfo)
  
  class FileElementType
    def validate(cgi)
      size = 0
      tempfile = cgi.get_attachment(@id)
      if tempfile then
        size = tempfile.stat.size
        mime_type = AttachmentHandler.get_mime_type(cgi, @id, tempfile.original_filename)
      end
      
      max_size = Config[:max_attachment_size] * 1024 # KBytes => Bytes
      
      return :err_no_mime_type if size != 0 && mime_type.empty?
      return :err_attachment_size if max_size > 0 && size > max_size
      
      true
    end
  end
  
  module AttachmentHandler
    
    def make_attachment(etype_id, load_from_session = true)
      tempfile = @cgi.get_attachment(etype_id)
      if load_from_session && (tempfile.nil? || tempfile.original_filename.empty?) then
        return load_attachment_from_session(etype_id)
      end
      
      if !(tempfile.nil? || tempfile.original_filename.empty?) then
        mime_type = get_mime_type(@cgi, etype_id, tempfile.original_filename)
        info = FileElementType::FileInfo.new2(tempfile, mime_type)
        Attachment.new(tempfile, info)
      else
        nil
      end
    end
    
    def store_attachments(project, message, attachments)
      attachments.each do |etype_id, attachment|
        value = []
        fileinfo = attachment.fileinfo
        size = attachment.tempfile.stat.size
        fileinfo.seq  = project.store_attachment(attachment.tempfile, fileinfo)
        element = message.element(etype_id)
        element.add_fileinfo(fileinfo)
        attachment.tempfile.close
      end
    end
    
    def save_attachments_to_session(report_type)
      result = {}
      
      report_type.each do |etype|
        next unless etype.kind_of?(FileElementType)
        
        unless etype.validate(@cgi) then
          @session[etype.id] = nil
          next
        end
        
        attachment = make_attachment(etype.id, false)
        unless attachment then
          @session[etype.id] = nil
          next
        end
        
        info = attachment.fileinfo
        @session[etype.id] = attachment.tempfile.read
        @session[etype.id + '_original_filename'] = attachment.tempfile.original_filename
        @session[etype.id + '_mime_type'] = info.mime_type
        @session[etype.id + '_size'] = info.size
        @session[etype.id + '_ctime'] = info.create_time
        
        result[etype.id] = info
        attachment.tempfile.close
      end
      
      result
    end
    
    def load_attachment_from_session(etype_id)
      return nil if @session[etype_id].nil? || @session[etype_id].empty?
      
      tempfile = Tempfile.new("attachment", Config[:tmp_dir])
      tempfile.binmode
      tempfile.print @session[etype_id]
      tempfile.rewind
      @session[etype_id] = nil
            
      name  = @session[etype_id + '_original_filename']
      type  = @session[etype_id + '_mime_type']
      size  = @session[etype_id + '_size'].to_i
      ctime = @session[etype_id + '_ctime']
      
      info = FileElementType::FileInfo.new(nil, name, size, type, '', ctime)
      
      Attachment.new(tempfile, info)
    end
    
    def get_mime_type(cgi, etype_id, filename)
      mime_type = cgi.get_param("#{etype_id}_mime_type", '')
      if mime_type.to_s.empty? || mime_type == 'auto' then
        mime_type = MimeType.new(filename).to_s
      elsif mime_type == 'binary' then
        mime_type = 'application/octet-stream'
      end
      mime_type
    end
    module_function :get_mime_type
    
  end

end
