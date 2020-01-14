=begin
  RSSAll - Make all project's RSS
=end

require 'kagemai/cgi/action'
require 'kagemai/message_bundle'
require 'kagemai/rdf'
require 'kagemai/cgi/action/rss'

module Kagemai  
  class RecentEntry
    def rdf_item_for_all(project)
      report  = project.load_report(@report_id)
      message = report.at(@message_id)
      
      title   = "#{@project_id}:#{@report_id}: "
      title  << message['title']
      url     = make_url(project)
      desc    = ''
      
      Thread.current[:Project] = project
      content = message.body
      author  = message['email'].gsub(/@.+/, '')
      
      item = RdfItem.new(title, url, @time, desc, content, author)
      item.xml # for pre-rendering BTS links
      item
    end
  end

  class RSSAll < Action
    def initialize(cgi, bts, mode, lang)
      super
    end
    
    def execute()
      @encoder = RSSEncoder.new(@lang)
      
      title   = Config[:rss_feed_title]
      rdf_url = make_url("action=#{RSSAll.name}")
      link    = make_url()
      desc    = ""
      author  = nil
      
      rdf = Rdf.new(title, rdf_url, link, desc, author, @encoder.encode, @lang)
      each_recent do |project, entry|
        begin
          rdf.add(entry.rdf_item_for_all(project))
        rescue
          $stderr.puts $@[0] + ": " + $!
        end
      end
      
      header = @cgi.header({'type' => 'text/xml'})
      RawActionResult.new(header, @encoder.do(rdf.xml))
    end
    
    def self.name()
      'rssall'
    end
    Action::add_action(self)
    
    def self.href(base_url, project_id)
      param = {'action' => name()}
      project_id ? nil : MessageBundle[:action_rssall].href(base_url, param)
    end
    
    def each_recent(max = 20)
      recent = []
      
      @bts.each_project do |project|
        project.each_recent do |entry|
          recent << [project, entry]
        end
      end
      
      recent = recent.sort_by{|project, entry| entry.time}.reverse
      max    = recent.size if recent.size < max
      
      recent[0...max].each {|project, entry| yield project, entry}
    end
    
  private    
    def make_url(param = nil)
      url =  Config[:base_url] + Mode::GUEST.url
      if param then
        url << (url.include?('?') ? "&" : "?")
        url << param
      end
      url
    end
  end
end
