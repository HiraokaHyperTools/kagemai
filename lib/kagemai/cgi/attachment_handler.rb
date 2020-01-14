=begin
  AttachmentHandler - 添付ファイルを処理するためのモジュールです  

  Copyright(C) 2002-2008 FUKUOKA Tomoyuki.

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

require 'kagemai/error'
require 'kagemai/elementtype'
require 'kagemai/mime_type'

module Kagemai
  Attachment = Struct.new(:tempfile, :fileinfo)

  module AttachmentHandler

    def make_attachment(etype_id, load_from_session = true)
      tempfile = @cgi.get_attachment(etype_id)
      if load_from_session && (tempfile.nil? || tempfile.original_filename.empty?) then
        return load_attachment_from_session(etype_id)
      end
      
      if !(tempfile.nil? || tempfile.original_filename.empty?) then
        mime_type = get_mime_type(etype_id, tempfile.original_filename)
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
    
    def validate_attachment(etype_id)
      size = 0
      tempfile = @cgi.get_attachment(etype_id)
      if tempfile then
        size = tempfile.stat.size
        mime_type = get_mime_type(etype_id, tempfile.original_filename)
        
        Logger.debug('AttachmentHander', 
                     "size = #{tempfile.stat.size}")
        Logger.debug('AttachmentHander', 
                     "mime_type = #{mime_type.inspect}")
      end
      
      max_size = Config[:max_attachment_size] * 1024 # KBytes => Bytes
      
      return [false, :err_no_mime_type] if size != 0 && mime_type.empty?
      return [false, :err_attachment_size] if max_size > 0 && size > max_size
      
      [true, nil]
    end
    
    def get_mime_type(etype_id, filename)
      mime_type = @cgi.get_param("#{etype_id}_mime_type", '')
      if mime_type.to_s.empty? || mime_type == 'auto' then
        mime_type = MimeType.new(filename).to_s
      elsif mime_type == 'binary' then
        mime_type = 'application/octet-stream'
      end
      mime_type
    end
  end

end
