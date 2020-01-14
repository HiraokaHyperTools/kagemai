=begin
  Kconv - NKF wrapper (No MIME decode)
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
    
    def conv(str, out_code, in_code)
      return str if out_code == in_code
      opt = '-m0'
      opt << in_code
      opt << out_code.downcase
      NKF::nkf(opt, str)
    end
    module_function :conv
    
    MAP = {
      'jis'        => JIS,
      'iso-2022-jp'=> JIS,
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
