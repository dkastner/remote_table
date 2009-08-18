class RemoteTable
  class Transform
    attr_accessor :select, :reject, :transform_class, :transform_options, :transform, :raw_table
    
    def initialize(bus)
      if transform_params = bus.delete(:transform)
        @transform_class = transform_params.delete(:class)
        @transform_options = transform_params
        @transform = @transform_class.new(@transform_options)
        @transform.add_hints!(bus)
      end
      @select = bus[:select]
      @reject = bus[:reject]
    end
    
    def apply(raw_table)
      self.raw_table = raw_table
      self
    end
    
    def each_row(&block)
      raw_table.each_row do |row|
        virtual_rows = transform ? transform.apply(row) : row # allow transform.apply(row) to return multiple rows
        Array.wrap(virtual_rows).each do |virtual_row|
          next if select and !select.call(virtual_row)
          next if reject and reject.call(virtual_row)
          yield virtual_row
        end
      end
    end
  end
end