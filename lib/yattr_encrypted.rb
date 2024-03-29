require 'openssl'
require 'active_support'
require 'base64'
require 'yattr_encrypted/railtie' if defined?(Rails)
require 'yattr_encrypted/version'

# how to use
#
#   class Foo < ActiveRecord::Base
#     yattr_encrypted :foo, :bar
#   end

# Adds attr_accessors that encrypt and decrypt an object's attributes
module YattrEncrypted
    
  ALGORITHM = 'aes-256-cbc'

  # Generates attr_accessors that encrypt and decrypt attributes transparently
  #
  # Options (any other options you specify are passed to the
  # encryptor's encrypt and decrypt methods)
  #
  #   :prefix A prefix used to generate the name of the referenced
  #            encrypted attributes.  For example <tt>attr_accessor
  #            :email, :password, :prefix => 'crypted_'</tt> would
  #            generate attributes named 'crypted_email' and
  #            'crypted_password' to store the encrypted email and
  #            password.  Defaults to ''.
  #
  #   :suffix A suffix used to generate the name of the referenced
  #            encrypted attributes.  For example <tt>attr_accessor
  #            :email, :password, :prefix => '', :suffix =>
  #            '_encrypted'</tt> would generate attributes named
  #            'email_encrypted' and 'password_encrypted' to store the
  #            encrypted email.  Defaults to '_encrypted'.
  #
  #   :key     The encryption key. Not generally required.
  #            Defaults to Rails.application.config.secret_token
  #
  # Example
  #
  #   class User
  #     yattr_encrypted :email
  #   end
  #
  #   @user = User.new
  #   @user.encrypted_email # nil? is true
  #   @user.email? # false
  #   @user.email = 'test@example.com'
  #   @user.email? # true
  #   @user.encrypted_email # returns the encrypted version of 'test@example.com'
  #

  def self.included(base)
    class << base
      attr_accessor :yate_encrypted_attributes

      def yattr_encrypted(*attributes)
        # construct options
        options = {
          :prefix           => '',
          :suffix           => '_encrypted',
          :key              => defined?(::Rails) ? ::Rails.application.config.secret_token : nil,
        }
        # merge specific options
        options.merge!(attributes.pop) if Hash === attributes.last

        # tell self to define instance methods from the database if they have not already been generated
        define_attribute_methods unless attribute_methods_generated?
        
        # schedule yattr_update_encrypted_values before save
        self.send :before_save, :yate_update_encrypted_values unless self.yate_encrypted_attributes

        # collect existing instance methods
        instance_methods_as_symbols = instance_methods.map { |method| method.to_sym }
 
        # iterate through attributes and create accessors, verify encryped accessors exist
        attributes.map { |x| x.to_sym }.each do |attribute|
          encrypted_attribute_name = [options[:prefix], attribute, options[:suffix]].join.to_sym

          # barf if reader and write doesn't exist for encrypted attribute
          raise ArgumentError.new("No Reader method for encrypted version of #{attribute}: #{encrypted_attribute_name}") \
              unless instance_methods_as_symbols.include?(encrypted_attribute_name)
          raise ArgumentError.new("No Write method for encrypted version of #{attribute}: #{encrypted_attribute_name}") \
              unless instance_methods_as_symbols.include?(:"#{encrypted_attribute_name}=")

          tmp =<<-XXX
          def #{attribute}
            options = yate_encrypted_attributes[:#{attribute}]
            if @#{attribute}.nil? || @#{attribute}.empty?
              @#{attribute} = #{encrypted_attribute_name} ? \
                  yate_decrypt(#{encrypted_attribute_name}, options[:key]) : \
                  ''
              if options[:read_filter].respond_to? :call
                  @#{attribute} = options[:read_filter].call(@#{attribute})
              elsif options[:read_filter]
                @#{attribute} = self.send options[:read_filter].to_sym, @#{attribute}
              end
              self.yate_checksums[:#{attribute}] = yate_attribute_hash_value(:#{attribute})
              self.yate_dirty[:#{attribute}] = true
            elsif options[:read_filter]
              if options[:read_filter].respond_to? :call
                @#{attribute} = options[:read_filter].call(@#{attribute})
              else
                @#{attribute} = self.send options[:read_filter].to_sym, @#{attribute}
              end
            end
            @#{attribute}
          end
          XXX
          class_eval(tmp)

          tmp =<<-XXX
          def #{attribute}= value
            options = yate_encrypted_attributes[:#{attribute}]
            if options[:write_filter].respond_to? :call
              value = options[:write_filter].call(value)
            elsif options[:write_filter]
              value = self.send options[:write_filter], value
            end
            @#{attribute} = value
            self.#{encrypted_attribute_name} = yate_encrypt(value, options[:key])
            self.yate_checksums[:#{attribute}] = yate_attribute_hash_value(:#{attribute})
            self.yate_dirty[:#{attribute}] = true
          end
          XXX
          class_eval(tmp)

          define_method("#{attribute}?") do
            value = send(attribute)
            value.respond_to?(:empty?) ? !value.empty? : !!value
          end

          self.yate_encrypted_attributes ||= {}

          self.yate_encrypted_attributes[attribute.to_sym] = \
              options.merge(:attribute => encrypted_attribute_name)

          # this conditioning is a hack to allow stand alone tests to work
          # one of these days 'real soon now' I'll figure out how to
          # stub out Rails::Railtie, but until then. . .
          if defined?(Rails)
            # add to filter_parameters keep out of log
            Rails.application.config.filter_parameters += [attribute, encrypted_attribute_name]

            # protect encrypted field from mass assignment
            attr_protected encrypted_attribute_name.to_sym
         end
        end
      end
    end
  end
  
  # protected methods - nobody needs to use these outside of the model
  protected
  
  def yate_checksums
    @yate_checksums ||= {}
  end

  def yate_dirty
    @yate_dirty ||= {}
  end

  def yate_encrypted_attributes
    self.class.yate_encrypted_attributes
  end

  private

  # yate_encrypt(value, key)
  #
  def yate_encrypt(value, key)
    cipher = OpenSSL::Cipher.new(ALGORITHM)
    cipher.encrypt
    cipher.key = key
    iv = cipher.random_iv   # ask OpenSSL for a new, random initial value
    
    # jsonify data
    value_marshalled = Marshal.dump value

    # encrypt data
    result = cipher.update value_marshalled
    result << cipher.final

    # return encrypted data and iv
    Base64.encode64(("%04d" % iv.length) + iv + result)
  end

  # yate_decrypt(encrypted_value, key)
  def yate_decrypt(marshalled_value, key)
    # initialize decryptor
    cipher = OpenSSL::Cipher.new(ALGORITHM)
    cipher.decrypt
    cipher.key = key
    
    # extract encrypted_value
    encrypted_value = Base64.decode64 marshalled_value

    # extract and set iv
    iv_end = encrypted_value[0..3].to_i + 3
    cipher.iv = encrypted_value[4..(iv_end)]
    encrypted_value = encrypted_value[(iv_end+1)..-1]

    # derypte and return
    result = cipher.update(encrypted_value)
    result << cipher.final
    
    Marshal.load result
  end

  # support for fields which are not atomic values
  def yate_attribute_hash_value(attribute)
    attribute = attribute.to_s if Symbol === attribute
    OpenSSL::HMAC.digest('md5', 'ersatz key', Marshal.dump(self.instance_variable_get("@#{attribute}")))
  end

  def yate_attribute_changed?(attribute)
    attribute = attribute.to_sym unless Symbol === attribute
    yate_attribute_hash_value(attribute) != self.yate_checksums[attribute] || self.yate_dirty[attribute]
  end
  
  def yate_update_encrypted_values
    return unless yate_encrypted_attributes
    yate_encrypted_attributes.each do |attribute, options|
      if yate_attribute_changed?(attribute)
        self.send "#{options[:attribute]}=".to_sym, yate_encrypt(self.send(attribute), options[:key])
        yate_dirty.delete(attribute)
      end
    end
  end

  # protected
  # 
  # # Returns yattr_encrypted options evaluated in the current object's scope for the attribute specified
  # def yate_evaluated_options_for(attribute)
  #   self.class.encrypted_attributes[attribute.to_sym].inject({}) do |hash, (option, value)|
  #     hash.merge!(option => yate_evaluate_option(value))
  #   end
  # end
  # 
  # # Evaluates symbol (method reference) or proc (responds to call) options
  # #
  # # If the option is not a proc then the original option is returned
  # def yate_evaluate_option(option)
  #   if option.respond_to?(:call)
  #     option.call(self)
  #   else
  #     option
  #   end
  # end
end
