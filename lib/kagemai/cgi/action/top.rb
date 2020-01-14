=begin
  Top - show project top page.

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
  class Top < Action
    def initialize(cgi, bts, mode, lang)
      super
      init_project()
    end
    
    def cache_type()
      'project'
    end
    
    def execute()
      body = eval_template('topics.rhtml', {:mode => @mode, :project => @project})
      ActionResult.new(MessageBundle[:title_top] % @project.name, 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end
    
    def self.name()
      'top'
    end
    Action::add_action(self)

    def self.href(base_url, project_id)
      param = {'action' => name(), 'project' => project_id}
      project_id ? MessageBundle[:action_top].href(base_url, param) : nil
    end
  end
end
