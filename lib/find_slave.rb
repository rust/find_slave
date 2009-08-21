module FindSlave
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def readonly(db_name)
      readonly_model = readonly_class(db_name)
      define_readonly_model_method(readonly_model)
      self.extend(FinderClassOverrideMethods)
    end

    private
    # create readonly base class
    def readonly_class(db_name)
      define_readonly_class(db_name) unless ActiveRecord.const_defined?(readonly_class_name(db_name))

      ActiveRecord.const_get(readonly_class_name(db_name))
    end

    # class name for readonly database
    def readonly_class_name(db_name)
      "#{db_name.camelize}"
    end

    # create parent class for readonly database access
    def define_readonly_class(db_name)
      ActiveRecord.module_eval %Q!
        class #{readonly_class_name(db_name)} < Base
          self.abstract_class = true
          establish_connection Rails.env + "_" + "#{db_name}"
        end
      !
    end

    def define_readonly_model_method(readonly_model)
      (class << self; self; end).class_eval do
        define_method(:readonly_model) { readonly_model }
      end
    end

    module FinderClassOverrideMethods
      # find from slave
      def find_slave(*args)
        klass_connection_pools = self.connection_handler.instance_variable_get(:@connection_pools)
        readonly_conn          = klass_connection_pools[readonly_model.name]
        default_conn           = klass_connection_pools[ActiveRecord::Base.name]

        begin
          klass_connection_pools[ActiveRecord::Base.name] = readonly_conn
          self.connection_handler.instance_variable_set(:@connection_pools, klass_connection_pools)

          self.find(*args)
        ensure
          klass_connection_pools[ActiveRecord::Base.name] = default_conn
          self.connection_handler.instance_variable_set(:@connection_pools, klass_connection_pools)
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, FindSlave)
