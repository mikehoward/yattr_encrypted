module YattrEncrypted
  class Railtie < Rails::Railtie
    initializer "active_record.initialize_yattr_encrypted" do
      ActiveSupport.on_load(:active_record) do
        class ActiveRecord::Base
          include YattrEncrypted
        end
      end
    end
  end
end
