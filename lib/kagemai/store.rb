=begin
  Store - interface of report manager
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
    
    def increment_view_count(report_id)
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
