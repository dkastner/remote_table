class RemoteTable
  class File
    attr_accessor :filename, :format, :delimiter, :skip, :cut, :crop, :sheet, :headers, :schema, :schema_name, :trap
    attr_accessor :encoding
    attr_accessor :path
    attr_accessor :keep_blank_rows
    attr_accessor :row_xpath
    attr_accessor :column_xpath
    
    def initialize(bus)
      @filename = bus[:filename]
      @format = bus[:format] || format_from_filename
      @delimiter = bus[:delimiter]
      @sheet = bus[:sheet] || 0
      @skip = bus[:skip] # rows
      @keep_blank_rows = bus[:keep_blank_rows] || false
      @crop = bus[:crop] # rows
      @cut = bus[:cut]   # columns
      @headers = bus[:headers]
      @schema = bus[:schema]
      @schema_name = bus[:schema_name]
      @trap = bus[:trap]
      @encoding = bus[:encoding] || 'UTF-8'
      @row_xpath = bus[:row_xpath]
      @column_xpath = bus[:column_xpath]
      extend "RemoteTable::#{format.to_s.camelcase}".constantize
    end
    
    def tabulate(path)
      define_fixed_width_schema! if format == :fixed_width and schema.is_a?(Array) # TODO move to generic subclass callback
      self.path = path
      self
    end
    
    private
    
    # doesn't support trap
    def define_fixed_width_schema!
      raise "can't define both schema_name and schema" if !schema_name.blank?
      self.schema_name = "autogenerated_#{filename.gsub(/[^a-z0-9_]/i, '')}".to_sym
      self.trap ||= lambda { |_| true }
      Slither.define schema_name do |d|
        d.rows do |row|
          row.trap(&trap)
          schema.each do |name, width, options|
            if name == 'spacer'
              row.spacer width
            else
              row.column name, width, options
            end
          end
        end
      end
    end
    
    def backup_file!
      FileUtils.cp path, "#{path}.backup"
    end
    
    def skip_rows!
      return unless skip
      RemoteTable.bang path, "tail -n +#{skip + 1}"
    end
    
    USELESS_CHARACTERS = [
      '\xef\xbb\xbf',   # UTF-8 byte order mark
      '\xc2\xad'        # soft hyphen, often inserted by MS Office (html: &shy;)
    ]
    def remove_useless_characters!
      RemoteTable.bang path, "perl -pe 's/#{USELESS_CHARACTERS.join '//g; s/'}//g'"
    end
    
    def convert_file_to_utf8!
      RemoteTable.bang path, "iconv -c -f #{Escape.shell_single_word encoding} -t UTF-8"
    end
    
    def restore_file!
      FileUtils.mv "#{path}.backup", path if ::File.readable? "#{path}.backup"
    end
    
    def cut_columns!
      return unless cut
      RemoteTable.bang path, "cut -c #{Escape.shell_single_word cut.to_s}"
    end
    
    def crop_rows!
      return unless crop
      RemoteTable.bang path, "tail -n +#{Escape.shell_single_word crop.first.to_s} | head -n #{crop.last - crop.first + 1}"
    end
    
    def format_from_filename
      extname = ::File.extname(filename).gsub('.', '')
      return :csv if extname.blank?
      format = [ :xls, :ods, :xlsx ].detect { |i| i == extname.to_sym }
      format = :html if extname =~ /\Ahtm/
      format = :csv if format.blank?
      format
    end
  end
end
