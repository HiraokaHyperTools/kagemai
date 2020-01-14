=begin
  Kconv - Kagemai Kanji converter. (No MIME decode)
  
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

require 'nkf'

module Kagemai
  module KKconv
    JIS  = 'J'
    SJIS = 'S'
    EUC  = 'E'
    UTF8 = 'W'
    AUTO = ''
    ASCII = ''
    
    def conv(str, out_code, in_code = AUTO)
      opt = '-m0'
      opt << in_code
      opt << out_code.downcase
      NKF::nkf(opt, str)
    end
    module_function :conv
    
    MAP = {
      'cp932'      => SJIS,
      'sjis'       => SJIS,
      'shift-jis'  => SJIS,
      'utf8'       => UTF8,
      'utf-8'      => UTF8,
      'euc'        => EUC,
      'euc-jp'     => EUC,
      'us-ascii'   => ASCII,
      'ascii'      => ASCII,
      'auto'       => AUTO,
    }
    
    def self.ckconv(str, to, from)
      conv(str, MAP[to.downcase], MAP[from.downcase])
    end
  end
  
end
