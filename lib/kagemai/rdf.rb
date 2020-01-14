=begin
  RDF - RDF class to make RSS
=end

module Kagemai
  class RSSEncoder
    def initialize(lang)
      @encode = 'UTF-8'
    end
    attr_reader :encode
    
    def do(s)
      s
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
