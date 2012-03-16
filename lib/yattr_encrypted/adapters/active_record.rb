if defined?(ActiveRecord::Base)
  module YattrEncrypted
    module Adapters
      module ActiveRecord
        # def self.extended(base) # :nodoc:
        #   base.class_eval do
        #     class << self
        #       alias_method_chain :method_missing, :yattr_encrypted
        #     end
        #   end
        # end

        protected

          # Ensures the attribute methods for db fields have been defined before calling the original 
          # <tt>yattr_encrypted</tt> method
          def yattr_encrypted(*attrs)
            define_attribute_methods rescue nil
            super
            attrs.reject { |attr| attr.is_a?(Hash) }.each { |attr| alias_method "#{attr}_before_type_cast", attr }
          end
      end
    end
  end

  ActiveRecord::Base.extend YattrEncrypted::Adapters::ActiveRecord
end