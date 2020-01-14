=begin
  Legend - LineChart legend

  Copyright(C) 2002-2004 FUKUOKA Tomoyuki.

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
  class Legend
    def initialize(ptsize = nil, font = nil)
      @items = []
      
      @ptsize = ptsize
      @font = font
      
      @margin  = 10
      @padding = 5
      
      @width = nil
      @height = nil
      
      @shadow_offset_x = 4
      @shadow_offset_y = 4
      
      @kconv_to   = Config[:gd_charset]
      @kconv_from = Config[:charset]
    end

    def add(text, color)
      @items << LegendItem.new(text.ckconv(@kconv_to, @kconv_from), @ptsize, color, @font)
    end
  
    def add_item(legend_item)
      @items << legend_item
    end

    def query_size(image)
      max_width  = 0
      total_height = @margin * 2
      
      @items.each do |item|
        width, height = item.query_size(image)
        max_width = width if width > max_width
        total_height += height + @padding
      end
      total_height -= @padding
      
      @width = max_width + @margin * 2
      @height = total_height
      
      [@width + @shadow_offset_x, @height + @shadow_offset_y]
    end
    
    def draw(image, x, y)
      query_size(image) unless @width
      draw_bg(image, x, y)
      
      x = x + @margin
      y = y + @margin
      @items.each do |item|
        width, height = item.draw(image, x, y)
        y += height + @padding
      end
    end
  
    def draw_bg(image, x, y)
      draw_shadow(image, x, y)
      
      bg = image.colorResolve(246, 245, 246)
      black = image.colorResolve(0, 0, 0)
      
      image.filledRectangle(x, y, x + @width - 1, y + @height - 1, bg)
      image.rectangle(x, y, x + @width - 1, y + @height - 1, black)
    end
  
    def draw_shadow(image, x, y)
      gray = image.colorResolve(160, 160, 160)
      
      x1 = x + @shadow_offset_x
      y1 = y + @shadow_offset_y
      x2 = x1 + @width - 1
      y2 = y1 + @height - 1
      
      image.filledRectangle(x1, y1, x2, y2, gray)
    end
  
  end # class Legend
  
  class LegendItem
    def initialize(text, ptsize, color, font)
      @text = text
      @ptsize = ptsize
      @color = color
      @font = font
      
      @line_thickness = 1
      @line_width = 15
      @line_margin = 5
      
      @width = nil
      @height = nil
      
      @text_angle = 0
      @text_offset_x = nil
      @text_offset_y = nil
      
      @line_offset_x = nil
      @line_offset_y = nil
    end
    
    def query_size(image)
      white = image.colorResolve(255, 255, 255)
      
      err, rect = image.stringTTF(white, @font, @ptsize, 0, 0, 0, @text)
      raise Error, err if err

      x1 = rect[6]; y1 = rect[7] # left-top
      x2 = rect[2]; y2 = rect[3] # right-bottom
      
      @width = x2 - x1 + @line_width + @line_margin
      @height = y2 - y1
      
      @text_offset_x = @line_width + @line_margin - x1
      @text_offset_y = 0 - y1
      
      @line_offset_x = 0
      @line_offset_y = (@height - @line_thickness) / 2
      
      [@width, @height]
    end
    
    def draw(image, x, y)
      query_size(image) unless @width

      color = @color
      case @color
      when String
        color = image.colorAllocate(@color)
      when Integer
        color = image.colorAllocate("#%06x" % @color)
      end
      draw_line(image, x, y, color)
      draw_text(image, x, y, color)
      
      [@width, @height]
    end
    
    def draw_line(image, x, y, color)
      x1 = x + @line_offset_x
      y1 = y + @line_offset_y
      x2 = x1 + @line_width
      y2 = y1 + @line_thickness
       image.filledRectangle(x1, y1, x2, y2, color)
    end
    
    def draw_text(image, x, y, color)
      text_x = x + @text_offset_x
      text_y = y + @text_offset_y
      image.stringTTF(color, @font, @ptsize, @text_angle, text_x, text_y, @text)
    end

  end # class LegendItem

end # module Kagemai
