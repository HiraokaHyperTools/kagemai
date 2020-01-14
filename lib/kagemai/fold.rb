=begin
  Fold - 文字の折り畳み処理(EUC専用、いちおう禁則処理付き)

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

module Kagemai

  module Fold
    $KCODE = 'EUC-JP'

    # EUC の 1byte, 2byte 目
    EUC_FIRST_CHAR  = /[\xa1-\xfe]/no
    EUC_SECOND_CHAR = /[\xa1-\xfe]/no

    # 行頭、行末禁則文字
    HEAD_PROHIBIT_REXP = /[。．、,，？！）＞≫』」”’ぁぃぅぇぉゃゅょっ]/o
    TAIL_PROHIBIT_REXP = /[（＜≪（“‘]/o

    # ASCII での折り畳み可能位置
    FOLDING_REXP = /[- \t]/

    # str を limit で折り畳み、折り畳み済みの String を返す。
    # 折り畳み後の各行の長さは、必ず limit 以下になる。
    def Fold.fold(str, length = 70)
      lines = str.collect{|line| fold_line(line, length)}
      lines.join('')
    end

    # line を折り畳む。line に改行が含まれていてはならない。
    # 折り畳み済みの文字列を返す。
    def Fold.fold_line(line, length)
      if line.size > length
        last_break_pos = line.size

        # lookup break position
        euc = false
        0.upto(length) do |i|
          if euc then
            euc = false

            # 行頭/行末禁則処理
            next if i < line.size - 2 && HEAD_PROHIBIT_REXP =~ line[i + 1, 2] 
            next if TAIL_PROHIBIT_REXP =~ line[i - 1, 2]

            last_break_pos = i
            next
          end
          
          if EUC_FIRST_CHAR =~ line[i, 1] then
            euc = true
            next
          end

          last_break_pos = i if FOLDING_REXP =~ line[i, 1]
        end
        
        # break line
        if last_break_pos <= length
          line = 
            line[0..last_break_pos] + "\n" + 
            fold_line(line[(last_break_pos + 1)..line.size], length)
        end
      end
      line
    end

  end

end
