=begin
  Projects - show projects list page.

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

require 'kagemai/cgi/action'
require 'kagemai/message_bundle'

module Kagemai
  class Projects < Action
    def execute()
      body = eval_template('projects.rhtml', {:bts => @bts})
      ActionResult.new(MessageBundle[:title_projects], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end
    
    def self.name()
      'projects'
    end
    Action::add_action(self)
    Action::set_default_action(self)
    
    def self.default?()
      true
    end
    
    def self.href(base_url, project_id)
      MessageBundle[:action_projects].href(base_url)
    end    
  end
end
