=begin
  error.rb - 影舞のエラークラスの定義

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
  class Error < RuntimeError; end
  class InitializeError < Error; end;
  class ParameterError < Error; end;
  class ConfigError < Error; end;
  class NoSuchElementError < Error; end
  class NoSuchTempalteError < Error; end
  class RepositoryError < Error; end
  class AuthorizationError < Error; end
  class NoSuchResourceError < Error; end
  class SecurityError < Error; end
  class InvalidOperationError < Error; end
  class InvalidHeaderError < Error; end
  class MailError < Error; end  
  class InvalidMailError < Error; end
  class SpamError < Error; end
end
