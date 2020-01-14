=begin
  Chart - draw summary char

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
=end

require 'GD'
require 'GDChart'

require 'kagemai/cgi/legend'

module Kagemai
  class LineChart
    class Line
      def initialize(color, data = [])
        @color = color
        @data = data
      end
      attr_reader :color, :data
      
      def add(data)
        @data << data
      end
      
      def size()
        @data.size
      end
    end
    
    def initialize(font)
      unless File.exist?(font) then
        raise ConfigError, "no such font - '#{font}'"
      end

      @font = font
      @ptsize = 10
      
      @labels = []
      @lines = {}
      @legend = Legend.new(@ptsize, @font)
      @legend_padding = 5
    end
    
    def add_label(label)
      @labels << label
    end
    
    def add_data(data, color, name)
      unless @lines.has_key?(name) then
        @lines[name] = Line.new(color)
        @legend.add(name, color)
      end
      @lines[name].add(data)
    end
    
    def add_line(name, color, data = [])
      @lines << Line.new(color, data)
      @legend.add(name, color)
    end
    
    def draw(width, height, filename)
      image = GD::Image.new(100, 100)
      @legend_width, @legend_height = @legend.query_size(image)
      image.destroy()
      
      chart_width  = width  - @legend_width
      chart_height = height
      
      draw_chart(chart_width, chart_height, filename)
      draw_legend(filename)
    end
    
    def draw_chart(width, height, filename)
      x_num = @lines.values[0].size
      line_num = @lines.size
      
      data = []
      ext_colors = []
      @lines.each do |name, line|
        data += line.data
        ext_colors += [line.color] * line.size
      end
      
      gdc = GDChart.new
      gdc.image_type = GDChart::PNG
      
      gdc.BGColor = 0xFFFFFF
      gdc.ExtColor = ext_colors
      gdc.transparent_bg = 1
      gdc.xaxis_angle = 0
      
      gdc.hard_size = true
      gdc.hard_xorig = 25
      gdc.hard_yorig = 0
      gdc.hard_graphwidth = width - 10
      gdc.hard_grapheight = height - 30

      # suppress warnings in Ruby-1.8
      nil_attrs = %w(
        BGImage SetColor ExtVolColor YLabelColor YLabel2Color
        XLabelColor YTitleColor YTitle2Color XTitleColor
        TitleColor VolColor PlotColor LineColor GridColor
        border thumbval thumblabel thumbnail scatter num_scatter_pts
        annotation annotation_font annotation_font_size annotation_ptsize
        HLC_cap_width HLC_style bar_width angle_3d  depth_3d stack_type
        yval_style yaxis2 yaxis xaxis ticks grid Shelf0 requested_yinterval
        requested_ymax requested_ymin interpolations ylabel_density
        xlabel_spacing xlabel_ctl ylabel2_fmt ylabel_fmt yaxis_ptsize 
        xaxis_ptsize xtitle_ptsize ytitle_ptsize title_ptsize yaxis_font
        xaxis_font xtitle_font ytitle_font title_font xaxisfont_size
        yaxisfont_size xtitle_size ytitle_size title_size title
        ytitle2 ytitle xtitle
      )
      
      nil_attrs.each do |attr|
        gdc.send(attr + '=', nil)
      end
      
      gdc.requested_yinterval = 1
      
      File.open(filename, 'w') do |file|
        gdc.out_graph(width, height, file, 
                      GDChart::LINE, x_num, @labels, line_num, data)
      end
    end
    
    def draw_legend(filename, marge = true)
      chart = nil
      File.open(filename, 'r') do |file|
        chart = GD::Image.newFromPng(file)
      end if marge
      
      width = height = legend_x = 0
      if chart then
        width  = chart.width + @legend_width + @legend_padding
        height = chart.height
        legend_x = chart.width + @legend_padding
      else
        im = GD::Image.new(100, 100)
        width, height = @legend.query_size(im)
        im.destroy
      end
      
      image = GD::Image.new(width, height)
      white = image.colorResolve(255, 255, 255)
      
      chart.copy(image, 0, 0, 0, 0, chart.width, chart.height) if chart
      @legend.draw(image, legend_x, 10)
      
      image.transparent(white)
      image.interlace = true
      
      File.open(filename, 'w') do |file|
        image.png file
      end
    end

  end # class LineChart

end # module Kagemai
