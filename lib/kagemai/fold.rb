=begin
  Fold - Folding string (UTF-8 version)
  
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

module Kagemai
  module Fold
    # Width of Japanese multibyte character
    JA_MBC_WIDTH = 2
    
    # 行頭、行末禁則文字
    JA_HEAD_PROHIBIT_RE = /[。．、,，？！）＞≫』」”’ぁぃぅぇぉゃゅょっ]/o
    JA_TAIL_PROHIBIT_RE = /[（＜≪（“‘]/o
    
    # ASCII での折り畳み可能位置
    FOLDING_RE = /[- \t]/
    
    # str を limit で折り畳み、折り畳み済みの String を返す。
    # 折り畳み後の各行の長さは、必ず limit 以下になる。
    def Fold.fold(str, length = 70)
      lines = str.collect{|line| fold_line(line, length)}
      lines.join('')
    end
    
    # line を折り畳む。line に改行が含まれていてはならない。
    # 折り畳み済みの文字列を返す。
    def Fold.fold_line(line, length)
      case Config[:language]
      when 'ja'
        fold_line_ja(line, length)
      else
        fold_line_m(line, length, 1)
      end
    end
    
    # 日本語おりたたみ（禁則処理つき）
    def Fold.fold_line_ja(line, length)
      mbc_line = line.scan(/.|\n/)
      width = mbc_line.inject(0){|t, s| t + (is_first_multibyte_char?(s[0]) ? JA_MBC_WIDTH : 1)}
      if width > length then
        last_break_pos = mbc_line.size
        width = 0
        i     = 0
        while (i < mbc_line.size) && (width <= length) do
          if FOLDING_RE =~ mbc_line[i]
            width += 1
            last_break_pos = i
          elsif is_first_multibyte_char?(mbc_line[i][0])
            width += JA_MBC_WIDTH
            unless JA_HEAD_PROHIBIT_RE =~ mbc_line[i] ||
                (i > 0 && JA_TAIL_PROHIBIT_RE =~ mbc_line[i - 1]) then
              last_break_pos = i - 1
            end
          else
            width += 1
          end
          i += 1
        end
        if last_break_pos > 0 && last_break_pos < mbc_line.size then
          line = mbc_line[0..last_break_pos].join + "\n" + 
            fold_line_ja(mbc_line[(last_break_pos + 1)..mbc_line.size].join, length)
        end
      end
      line
    end
    
    # 日本語以外の折りたたみ
    def Fold.fold_line_m(line, length, mbc_width)
      mbc_line = line.scan(/.|\n/)
      width = mbc_line.inject(0){|t, s| t + (is_first_multibyte_char?(s[0]) ? mbc_width : 1)}
      if width > length then
        last_break_pos = mbc_line.size
        width = 0
        i     = 0
        while (i < mbc_line.size) && (width <= length) do
          if FOLDING_RE =~ mbc_line[i]
            width += 1
            last_break_pos = i
          elsif is_first_multibyte_char?(mbc_line[i][0])
            width += mbc_width
            last_break_pos = i - 1
          else
            width += 1
          end
          i += 1
        end
        line = mbc_line[0..last_break_pos].join + "\n" + 
          fold_line_m(mbc_line[(last_break_pos + 1)..mbc_line.size].join, length, mbc_width)
      end
      line
    end
    
    def Fold.is_first_multibyte_char?(ch)
      (ch & 0xc0) ==  0xc0
    end
    
    def Fold.mbc_width(str)
      case Config[:language]
      when 'ja'
        mbc_width = JA_MBC_WIDTH
      else
        mbc_width = 1
      end
      mbc_line = str.scan(/.|\n/)
      mbc_line.inject(0){|t, s| t + (is_first_multibyte_char?(s[0]) ? mbc_width : 1)}
    end
  end

end

# -Ku オプションつきで実行すること
if $0 == __FILE__ then
  module Kagemai
    class Config
      def self.[](key)
        'ja'
      end
    end
  end
  
  str = "１２３４５６７８９"
  puts Kagemai::Fold.fold(str, 8)
  
  # 行頭禁則文字チェック
  str = 'きょうはいい、天気です。'
  puts Kagemai::Fold.fold(str, 12)
  
  # 行末禁則文字チェック
  str = 'きょうはいい（天気）です。'
  puts Kagemai::Fold.fold(str, 14)
end
