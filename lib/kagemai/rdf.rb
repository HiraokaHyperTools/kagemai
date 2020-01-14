=begin
  RDF - RDF class to make RSS
  
  Copyright(C) 2005,2008 FUKUOKA Tomoyuki.
  
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
  
  $Id: rdf.rb 392 2008-02-21 13:40:44Z fukuoka $
=end

module Kagemai
  class RSSEncoder
    def initialize(lang)
      @encode = 'UTF-8'
      case lang
      when 'ja'
        @encode = 'EUC-JP'
        if RUBY_VERSION > "1.8.3" then
          @encode = 'UTF-8'
          @encoder = Proc.new{|s| KKconv::conv(s, KKconv::UTF8, KKconv::EUC)}
        else
          @encoder = uconv_encoder()
        end
      when 'en'
      end
      @encoder = Proc.new{|s| s} unless @encoder
    end
    attr_reader :encode
    
    def do(s)
      @encoder.call(s)
    end
    
  private
    def uconv_encoder()
      begin
        require 'uconv'
        @encode = 'UTF-8'
        Proc.new {|s| Uconv.euctou8( s ) }
      rescue LoadError
      end
    end
  end

  class Rdf
    def initialize(title, rdf_url, link, description, author, 
                   encode = 'UTF-8', lang = 'ja-JP')
      @title   = title.to_s
      @rdf_url = rdf_url.to_s
      @link    = link.to_s
      @description = description.to_s
      @author  = author.to_s
      
      @encode = encode
      @lang   = lang
      
      @items  = []
    end
    
    def add(item)
      @items << item
    end
    
    def xml()
      result  = header()
      result << channel()
      @items.each do |item|
        result << item.xml
      end
      result + footer()
    end
    
  private
    def header()
      %Q!<?xml version="1.0" encoding="#{@encode}"?>
         <rdf:RDF xmlns="http://purl.org/rss/1.0/" 
                  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" 
                  xmlns:dc="http://purl.org/dc/elements/1.1/" 
                  xmlns:content="http://purl.org/rss/1.0/modules/content/" 
                  xml:lang="#{@lang}">
      !
    end
    
    def channel()
      result = %Q!
         <channel rdf:about="#{@rdf_url.escape_h}">
           <title>#{@title.escape_h}</title>
           <link>#{@link.escape_h}</link>
           <description>#{@description.escape_h}</description>
           <dc:creator>#{@author.escape_h}</dc:creator>
           <items>
             <rdf:Seq>
      !
      
      @items.each do |item|
        result << '         ' + item.seq
      end
      
      result << %Q!
             </rdf:Seq>
           </items>
         </channel>
      !
    end
    
    def footer()
      "</rdf:RDF>\n"
    end
  end
  
  class RdfItem
    def initialize(title, url, date, description = nil, content = nil, author = nil)
      @title       = title
      @url         = url
      @date        = date
      @description = description
      @content     = content
      @author      = author
      @xml         = nil
    end
    
    def seq()
      %Q!<rdf:li resource="#{@url.escape_h}"/>!
    end
    
    def xml()
      return @xml if @xml
      
      result = %Q!
        <item rdf:about="#{@url.escape_h}">
          <author>#{@author.escape_h}</author>
          <title>#{@title.escape_h}</title>
          <link>#{@url.escape_h}</link>
          <dc:date>#{time_string()}</dc:date>
      !
      
      if @description && @description.size > 0 then
        result << "    <description>#{@description.escape_h}\n"
        result << "    </description>\n"
      end
      
      if @content then
        result << "    <content:encoded><![CDATA[\n"
        result << @content.escape_h + "\n"
        result << "    ]]></content:encoded>\n"
      end
      
      result << "  </item>\n"
      
      @xml = result
    end
    
    def <=>(other)
      other.date <=> @date
    end
    attr_reader :date
    
  private
    def time_string
      g = @date.dup.gmtime
      l = Time::local( g.year, g.month, g.day, g.hour, g.min, g.sec )
      tz = (g.to_i - l.to_i)
      zone = sprintf( "%+03d:%02d", tz / 3600, tz % 3600 / 60 )
      @date.strftime( "%Y-%m-%dT%H:%M:%S" ) + zone
    end
    
  end
end
