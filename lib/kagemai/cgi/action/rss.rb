=begin
  RSS - Make RSS
  
  Copyright(C) 2005 FUKUOKA Tomoyuki.
  
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
  
  $Id: rss.rb 402 2008-02-22 16:54:41Z fukuoka $  
=end

require 'kagemai/cgi/action'
require 'kagemai/message_bundle'
require 'kagemai/rdf'

module Kagemai
  class RecentEntry
    def rdf_item(project)
      report  = project.load_report(@report_id)
      message = report.at(@message_id)
      
      title   = message['title']
      url     = make_url(project)
      desc    = ''
      content = message.body
      author  = message['email'].gsub(/@.+/, '')
      
      RdfItem.new(title, url, @time, desc, content, author)
    end
    
  private
    def make_url(project)
      url =  Config[:base_url] + Mode::GUEST.url
      url << (url.include?('?') ? "&" : "?")
      url << "project=#{project.id}&action=#{ViewReport.name}"
      url << "&id=#{@report_id}\##{@message_id}"
      url
    end
  end
  
  class RSS < Action
    def initialize(cgi, bts, mode, lang)
      super
      init_project()
    end
    
    def cache_type()
      'project'
    end
    
    def execute()
      @encoder = RSSEncoder.new(@lang)
      
      title   = @project.name
      rdf_url = make_url() + "action=#{RSS.name}"
      link    = make_url()
      desc    = ""
      author  = nil
      
      rdf = Rdf.new(title, rdf_url, link, desc, author, @encoder.encode, @lang)
      @project.each_recent do |entry|
        begin
          rdf.add(entry.rdf_item(@project))
        rescue
          $stderr.puts $@[0] + ": " + $!
        end
      end
      
      header = @cgi.header({'type' => 'text/xml'})
      RawActionResult.new(header, @encoder.do(rdf.xml))
    end
    
    def self.name()
      'rss'
    end
    Action::add_action(self)
    
    def self.href(base_url, project_id)
      param = {'action' => name(), 'project' => project_id}
      project_id ? 'RSS'.href(base_url, param) : nil
    end
    
  private
    def make_url()
      url =  Config[:base_url] + Mode::GUEST.url
      url << (url.include?('?') ? "&" : "?")
      url << "project=#{@project.id}"
    end
  end
end
