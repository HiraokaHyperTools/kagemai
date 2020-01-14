=begin
  Store - define interface for saving reports

  Copyright(C) 2002-20008 FUKUOKA Tomoyuki.

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
  class Store
    def self.obsolete?()
      false
    end
    
    def initialize(dir, project_id, report_type, charset)
      @dir = dir
      @project_id = project_id
      @report_type = report_type
      @charset = charset
      @has_transaction = true
    end

    # close data base
    def close()
    end
    
    # store Report
    def store(report)
      raise NotImplementedError, 'A subclass must override this method.'
    end

    # load Report
    def load(report_type, id)
      raise NotImplementedError, 'A subclass must override this method.'
    end

    # get next Report id
    def next_id()
      raise NotImplementedError, 'A subclass must override this method.'
    end

    def size()
      raise NotImplementedError, 'A subclass must override this method.'
    end

    def each(&block)
      raise NotImplementedError, 'A subclass must override this method.'
    end

    def transaction(&block)
      raise NotImplementedError, 'A subclass must override this method.'
    end
    
    FileInfo = Struct.new(:name, :size)
    
    def store_attachment(attachment, fileinfo)
      raise NotImplementedError, 'A subclass must override this method.'
    end
    
    def get_attachment_filename(seq_id)
      raise NotImplementedError, 'A subclass must override this method.'
    end

    def add_element_type(etype)
      raise NotImplementedError, 'A subclass must override this method.'
    end

    def delete_element_type(etype_id)
      raise NotImplementedError, 'A subclass must override this method.'
    end

    SearchResult = Struct.new('SearchResult', 
                              :total, 
                              :limit, 
                              :offset, 
                              :reports,
                              :params)

    def search(report_type, cond_attr, cond_other, and_op, limit, offset, order)
      raise NotImplementedError, 'A subclass must override this method.'
    end
  end
end
