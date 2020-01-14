=begin
  mime_type.rb

  Copyright(C) 2004 FUKUOKA Tomoyuki.

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
  class MimeType
    TEXT_TYPES = {
      "txt"   => "text/plain",
      "rb"    => "text/plain",
      "rd"    => "text/plain",
      "c"     => "text/plain",
      "c++"   => "text/plain",
      "cxx"   => "text/plain",
      "cpp"   => "text/plain",
      "pl"    => "text/plain", 
      "py"    => "text/plain", 
      "sh"    => "text/plain", 
      "java"  => "text/plain",
      "patch" => "text/plain",
      "html"  => "text/html",
      "htm"   => "text/html",
      "rhtm"  => "text/html",
      "css"   => "text/css",
      "xml"   => "text/xml",
      "xsl"   => "text/xsl",
    }
    
    IMAGE_TYPES = {
      "gif"   => "image/gif",
      "jpeg"  => "image/jpeg",
      "jpg"   => "image/jpeg",
      "png"   => "image/png",
      "bmp"   => "image/bmp",
    }
    
    TYPES = {
      "doc"   => "application/msword",
      "xls"   => "application/vnd.ms-excel",
      "pdf"   => "application/pdf",
    }
    TYPES.update(TEXT_TYPES)
    TYPES.update(IMAGE_TYPES)
    TYPES.default = "application/octet-stream"
    
    def initialize(name)
      @extension = /\.([^.]+)$/.match(name).to_a[1]
      @mime_type = TYPES[@extension]
    end
    
    def to_s
      @mime_type
    end
    
    def text?()
      TEXT_TYPES.has_key?(@extension)
    end
    
    def image?()
      IMAGE_TYPES.has_key?(@extension)
    end
  end
end
