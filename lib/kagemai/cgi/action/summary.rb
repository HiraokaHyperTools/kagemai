=begin
  Summary
=end

require 'kagemai/cgi/action'
require 'kagemai/util'
require 'kagemai/message_bundle'
require 'kagemai/daterange'

require 'parsedate'

module Kagemai
  class Summary < Action
    def self.name()
      'summary'
    end
    Action::add_action(self)
    
    SummaryItem = Struct.new(:new, :open, :close, :reply, :opened, :closed, :total)
    SummaryMonthItem = Struct.new(:new, :open, :close, :reply, :cumm_opened, :cumm_closed, :total)
    
    def initialize(cgi, bts, mode, lang)
      super
      init_project()
    end
    
    def cache_key()
      month = @cgi.get_param('month', '')
      self.class.name + '_' + month
    end
    
    def cache_type()
      'project'
    end
    
    def execute()
      summary = get_summary()
      
      summary_by_month = []
      current_month = nil
      
      opened = closed = total = 0
      summary.each do |day, item|
        opened += item.open
        closed += item.close
        total  += item.new
        item.opened = opened
        item.closed = closed
        item.total  = total
        
        month = day[/^\d\d\d\d\/\d\d/]
        unless current_month == month then
          summary_by_month << [month, SummaryMonthItem.new(0, 0, 0, 0, 0, 0, 0)]
          current_month = month
        end
        summary_by_month.last[1].new   += item.new
        summary_by_month.last[1].open  += item.open
        summary_by_month.last[1].close += item.close
        summary_by_month.last[1].reply += item.reply
        summary_by_month.last[1].cumm_opened = item.opened
        summary_by_month.last[1].cumm_closed = item.closed
        summary_by_month.last[1].total = item.total
      end
      
      month = @cgi.get_param('month')
      body = nil
      
      unless month then
        summary_by_month = complement_month(summary_by_month)
        chart_url = create_summary_chart(summary_by_month)
        
        param = {
          :mode => @mode, 
          :project => @project, 
          :summary => summary,
          :summary_by_month => summary_by_month,
          :chart_url => chart_url
        }
        body = eval_template('summary.rhtml', param)
      else
        summary = get_summary_of_month(summary, month)
        
        param = {
          :mode => @mode, 
          :project => @project, 
          :summary => summary,
          :month   => month
        }
        body = eval_template('summary_month.rhtml', param)
      end

      ActionResult.new(MessageBundle[:title_summary], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end
    
    def get_summary()
      summary = {}
      @project.each do |report|
        opened  = nil
        report.each do |message|
          t = message.time.format_date(@lang)
          unless summary.has_key?(t) then
            summary[t] = SummaryItem.new(0, 0, 0, 0, 0, 0, 0)
          end
          
          if opened.nil? then
            summary[t].new += 1
          else
            summary[t].reply += 1
          end
          
          if message.open? then
            summary[t].open  += 1 unless opened
            summary[t].close -= 1 if opened == false
            opened = true
          else
            summary[t].open  -= 1 if opened == true
            summary[t].close += 1 unless opened == false
            opened = false
          end
        end
      end
      
      summary = summary.sort{|a, b| a[0] <=> b[0]} # sort by date
    end
    
    def complement_month(summary)
      return summary if summary.nil? || summary.size == 0
      
      current = 0
      comp_summary = []
      today = Date.today
      range = DateRange.new(summary.first[0] + '/01', "#{today.year}/#{today.month}/31")
      
      range.each_month() do |year, month|
        month_str = "%04d/%02d" % [year, month]
        
        if current < summary.size && summary[current][0] == month_str then
          comp_summary << summary[current]
          current += 1
        else
          prev_item = summary[current - 1][1]
          item = SummaryMonthItem.new(0, 
                                      0, 
                                      0,
                                      0,
                                      prev_item.cumm_opened, 
                                      prev_item.cumm_closed, 
                                      prev_item.total)
          
          comp_summary << [month_str, item]
        end
      end
      
      comp_summary
    end
    
    def get_summary_of_month(summary, month)
      last_item_of_prev_month = SummaryItem.new(0, 0, 0, 0, 0, 0, 0)
      
      hit = false
      month_re = /^#{month.gsub(/-/, '/')}/
      summary = summary.collect{|day, item|
        if month_re =~ day then
          hit = true
          [day, item]
        else
          last_item_of_prev_month = item unless hit
          nil
        end
      }.compact
      
      start_date = month + "-01"
      end_date   = month + "-31"
      
      year, mon = ParseDate.parsedate(month + "-01")[0..1]
      current_time = Time.new
      if year == current_time.year && mon == current_time.month then
        end_date = current_time.strftime("%Y/%m/%d")
      end
      
      range = DateRange.new(start_date, end_date)
      pos = 0
      prev_item = last_item_of_prev_month
      comp_summary = []
      
      range.each_day() do |year, month, day|
        date = Time.local(year, month, day).format_date(@lang)
        if pos < summary.size && date == summary[pos][0] then
          comp_summary << summary[pos]
          prev_item = summary[pos][1]
          pos += 1
        else
          item = SummaryItem.new(0, 0, 0, 0, prev_item.opened, prev_item.closed, prev_item.total)
          comp_summary << [date, item]
        end
      end
      
      comp_summary
    end

    def create_summary_chart(summary)
      return nil if summary.size == 0
      return nil unless Config[:enable_gdchart]
      
      require 'kagemai/cgi/chart'
      
      # chart dir: CGI のディレクトリ + /summary
      # filename : project_id + summry_by_month.png
      # URL      : summary/ + filename
      # open/reply/close/cumm_open/cumm_close/total を月ごとに。
      
      cgi_path = ENV['PATH_TRANSLATED'] || ENV['SCRIPT_FILENAME']
      dir = File.dirname(cgi_path.dup.untaint) + '/summary'
      
      filename = @project.id + '_summary.png'
      url = 'summary/' + filename
      
      Dir.mkdir(dir) unless File.exist?(dir)
      path = dir + '/' + filename      
      
      chart = LineChart.new(Config[:gd_font])
      
      summary = summary.dup
      min_month = 6
      if summary.size < min_month then
        null_summary = SummaryMonthItem.new(0, 0, 0, 0, 0, 0, 0)
        sy, sm = summary[0][0].split(/\//)
        ym = Date.new(sy.to_i, sm.to_i)
        (summary.size...min_month).each do |i|
          ym = ym << 1
          summary.unshift(["#{ym.year}/#{ym.month}", null_summary])
        end
      end

      summary.each do |ym, item|
        chart.add_label(ym)
        chart.add_data(item.new,
                       0xff6699, MessageBundle[:summry_legend_new])
        chart.add_data(item.reply,
                       0x33dd33, MessageBundle[:summry_legend_reply])
        chart.add_data(item.close,
                       0x336666, MessageBundle[:summry_legend_close])
        chart.add_data(item.cumm_opened,
                       0xff0000, MessageBundle[:summry_legend_cumm_open])
        chart.add_data(item.cumm_closed,
                       0x0000ff, MessageBundle[:summry_legend_cumm_close])
        chart.add_data(item.total,
                       0x009933, MessageBundle[:summry_legend_total])
      end
      
      width  = 600
      height = 250
      chart.draw(width, height, path)
      
      return url
    end
    
    def self.href(base_url, project_id)
      param = {'action' => name(), 'project' => project_id}
      project_id ? MessageBundle[:action_summary].href(base_url, param) : nil
    end    
  end
  
end
