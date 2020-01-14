=begin
  Fold - ʸ�����ޤ���߽���(EUC���ѡ�����������§�����դ�)

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

    # EUC �� 1byte, 2byte ��
    EUC_FIRST_CHAR  = /[\xa1-\xfe]/no
    EUC_SECOND_CHAR = /[\xa1-\xfe]/no

    # ��Ƭ��������§ʸ��
    HEAD_PROHIBIT_REXP = /[������,�������ˡ��١סɡǤ��������������]/o
    TAIL_PROHIBIT_REXP = /[�ʡ��ʡȡ�]/o

    # ASCII �Ǥ��ޤ���߲�ǽ����
    FOLDING_REXP = /[- \t]/

    # str �� limit ���ޤ���ߡ��ޤ���ߺѤߤ� String ���֤���
    # �ޤ���߸�γƹԤ�Ĺ���ϡ�ɬ�� limit �ʲ��ˤʤ롣
    def Fold.fold(str, length = 70)
      lines = str.collect{|line| fold_line(line, length)}
      lines.join('')
    end

    # line ���ޤ���ࡣline �˲��Ԥ��ޤޤ�Ƥ��ƤϤʤ�ʤ���
    # �ޤ���ߺѤߤ�ʸ������֤���
    def Fold.fold_line(line, length)
      if line.size > length
        last_break_pos = line.size

        # lookup break position
        euc = false
        0.upto(length) do |i|
          if euc then
            euc = false

            # ��Ƭ/������§����
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
