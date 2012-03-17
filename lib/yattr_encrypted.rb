# Adds attr_accessors that encrypt and decrypt an object's attributes
module YattrEncrypted
  module Encryptor
    require 'openssl'
    
    ALGORITHM = 'aes-256-cbc'

    # yattr_encrypted_encrypt(value, key)
    #
     def yattr_encrypted_encrypt(value, key)
      cipher = OpenSSL::Cipher.new(ALGORITHM)
      cipher.encrypt
      cipher.key = key
      iv = cipher.random_iv
      
      # encrypt data
      result = cipher.update value
      result << cipher.final
      
      # return encrypted data and iv
      ("%04d" % iv.length) + iv + result
    end

    # yattr_encrypted_decrypt(encrypted_value, key)
    def yattr_encrypted_decrypt(encrypted_value, key)
      # initialize decryptor
      cipher = OpenSSL::Cipher.new(ALGORITHM)
      cipher.decrypt
      cipher.key = key
      
      # extract and set iv
      iv_end = encrypted_value[0..3].to_i + 3
      cipher.iv = encrypted_value[4..(len)]
      encrypted_value = encrypted_value[(len+1)..-1]
      
      # derypte and return
      result = cipher.update(encrypted_value)
      result << cipher.final
    end
  end

  autoload :Version, 'yattr_encrypted/version'

  def self.extended(base) # :nodoc:
    base.class_eval do
      include InstanceMethods
      attr_writer :yattr_encrypted_options
      @yattr_encrypted_options, @encrypted_attributes = {}, {}
    end
  end

  # Generates attr_accessors that encrypt and decrypt attributes transparently
  #
  # Options (any other options you specify are passed to the encryptor's encrypt and decrypt methods)
  #
  #   :prefix           => A prefix used to generate the name of the referenced encrypted attributes.
  #                        For example <tt>attr_accessor :email, :password, :prefix => 'crypted_'</tt> would
  #                        generate attributes named 'crypted_email' and 'crypted_password' to store the
  #                        encrypted email and password. Defaults to 'encrypted_'.
  #
  #   :suffix           => A suffix used to generate the name of the referenced encrypted attributes.
  #                        For example <tt>attr_accessor :email, :password, :prefix => '', :suffix => '_encrypted'</tt>
  #                        would generate attributes named 'email_encrypted' and 'password_encrypted' to store the
  #                        encrypted email. Defaults to ''.
  #
  #   :key              => The encryption key. This option may not be required if you're using a custom encryptor. If you pass
  #                        a symbol representing an instance method then the :key option will be replaced with the result of the
  #                        method before being passed to the encryptor. Objects that respond to :call are evaluated as well (including procs).
  #                        Any other key types will be passed directly to the encryptor.
  #
  # Example
  #
  #   class User
  #     yattr_encrypted :email
  #   end
  #
  #   @user = User.new
  #   @user.email_encrypted # nil? is true
  #   @user.email? # false
  #   @user.email = 'test@example.com'
  #   @user.email? # true
  #   @user.email_encrypted # returns the encrypted version of 'test@example.com'
  #
  def yattr_encrypted(*attributes)
    options = {
      :prefix           => '',
      :suffix           => '_encrypted',
      :key              => Rails.application.config.secret_token,
    }.merge!(yattr_encrypted_options).merge!(attributes.last.is_a?(Hash) ? attributes.pop : {})

    attributes.each do |attribute|
      encrypted_attribute_name = (options[:attribute] ? options[:attribute] : [options[:prefix], attribute, options[:suffix]].join).to_sym

      instance_methods_as_symbols = instance_methods.collect { |method| method.to_sym }
      attr_reader encrypted_attribute_name \
          unless instance_methods_as_symbols.include?(encrypted_attribute_name)
      attr_writer encrypted_attribute_name \
          unless instance_methods_as_symbols.include?(:"#{encrypted_attribute_name}=")

      define_method(attribute) do
        instance_variable_get("@#{attribute}") || \
          instance_variable_set("@#{attribute}", 
            decrypt(attribute, send(encrypted_attribute_name)))
      end

      define_method("#{attribute}=") do |value|
        send("#{encrypted_attribute_name}=", encrypt(attribute, value))
        instance_variable_set("@#{attribute}", value)
      end

      define_method("#{attribute}?") do
        value = send(attribute)
        value.respond_to?(:empty?) ? !value.empty? : !!value
      end

      encrypted_attributes[attribute.to_sym] = \
          options.merge(:attribute => encrypted_attribute_name)
    end
  end
  alias_method :attr_encryptor, :yattr_encrypted

  # Default options to use with calls to <tt>yattr_encrypted</tt>
  #
  # It will inherit existing options from its superclass
  def yattr_encrypted_options
    @yattr_encrypted_options ||= superclass.yattr_encrypted_options.dup
  end

  # Checks if an attribute is configured with <tt>yattr_encrypted</tt>
  #
  # Example
  #
  #   class User
  #     attr_accessor :name
  #     yattr_encrypted :email
  #   end
  #
  #   User.yattr_encrypted?(:name)  # false
  #   User.yattr_encrypted?(:email) # true
  def yattr_encrypted?(attribute)
    encrypted_attributes.has_key?(attribute.to_sym)
  end

  # Decrypts a value for the attribute specified
  #
  # Example
  #
  #   class User
  #     yattr_encrypted :email
  #   end
  #
  #   email = User.decrypt(:email, 'SOME_ENCRYPTED_EMAIL_STRING')
  def decrypt(attribute, encrypted_value, options = {})
    options = encrypted_attributes[attribute.to_sym].merge(options)
    if options[:if] && !options[:unless] && !encrypted_value.nil? && !(encrypted_value.is_a?(String) && encrypted_value.empty?)
      encrypted_value = encrypted_value.unpack(options[:encode]).first if options[:encode]
      value = options[:encryptor].send(options[:decrypt_method], options.merge!(:value => encrypted_value))
      value = options[:marshaler].send(options[:load_method], value) if options[:marshal]
      value
    else
      encrypted_value
    end
  end

  # Encrypts a value for the attribute specified
  #
  # Example
  #
  #   class User
  #     yattr_encrypted :email
  #   end
  #
  #   encrypted_email = User.encrypt(:email, 'test@example.com')
  def encrypt(attribute, value, options = {})
    options = encrypted_attributes[attribute.to_sym].merge(options)
    if options[:if] && !options[:unless] && !value.nil? && !(value.is_a?(String) && value.empty?)
      value = options[:marshal] ? options[:marshaler].send(options[:dump_method], value) : value.to_s
      encrypted_value = options[:encryptor].send(options[:encrypt_method], options.merge!(:value => value))
      encrypted_value = [encrypted_value].pack(options[:encode]) if options[:encode]
      encrypted_value
    else
      value
    end
  end

  # Contains a hash of encrypted attributes with virtual attribute names as keys
  # and their corresponding options as values
  #
  # Example
  #
  #   class User
  #     yattr_encrypted :email, :key => 'my secret key'
  #   end
  #
  #   User.encrypted_attributes # { :email => { :attribute => 'encrypted_email', :key => 'my secret key' } }
  def encrypted_attributes
    @encrypted_attributes ||= superclass.encrypted_attributes.dup
  end

  # Forwards calls to :encrypt_#{attribute} or :decrypt_#{attribute} to the corresponding encrypt or decrypt method
  # if attribute was configured with yattr_encrypted
  #
  # Example
  #
  #   class User
  #     yattr_encrypted :email, :key => 'my secret key'
  #   end
  #
  #   User.encrypt_email('SOME_ENCRYPTED_EMAIL_STRING')
  def method_missing(method, *arguments, &block)
    if method.to_s =~ /^((en|de)crypt)_(.+)$/ && yattr_encrypted?($3)
      send($1, $3, *arguments)
    else
      super
    end
  end

  module InstanceMethods
    # Decrypts a value for the attribute specified using options evaluated in the current object's scope
    #
    # Example
    #
    #  class User
    #    attr_accessor :secret_key
    #    yattr_encrypted :email, :key => :secret_key
    #
    #    def initialize(secret_key)
    #      self.secret_key = secret_key
    #    end
    #  end
    #
    #  @user = User.new('some-secret-key')
    #  @user.decrypt(:email, 'SOME_ENCRYPTED_EMAIL_STRING')
    def decrypt(attribute, encrypted_value)
      options = evaluated_yattr_encrypted_options_for(attribute)
      if options[:iv]
        # pos is the offset into encrypted_value of the last character of the iv
        pos = encrypted_value[0..3].to_i + 3
        options[:iv] = encrypted_value[4..(pos)]
        encrypted_value = encrypted_value[(pos+1)..-1]
      end
      self.class.decrypt(attribute, encrypted_value, options)
    end

    # Encrypts a value for the attribute specified using options evaluated in the current object's scope
    #
    # Example
    #
    #  class User
    #    attr_accessor :secret_key
    #    yattr_encrypted :email, :key => :secret_key
    #
    #    def initialize(secret_key)
    #      self.secret_key = secret_key
    #    end
    #  end
    #
    #  @user = User.new('some-secret-key')
    #  @user.encrypt(:email, 'test@example.com')
    def encrypt(attribute, value)
      options = evaluated_yattr_encrypted_options_for(attribute)
      if options[:iv]
        ("%04d" % options[:iv].length) + options[:iv] + self.class.encrypt(attribute, value, options)
      else
        self.class.encrypt(attribute, value, options)
      end
    end

    protected

      # Returns yattr_encrypted options evaluated in the current object's scope for the attribute specified
      def evaluated_yattr_encrypted_options_for(attribute)
        self.class.encrypted_attributes[attribute.to_sym].inject({}) { |hash, (option, value)| hash.merge!(option => evaluate_yattr_encrypted_option(value)) }
      end

      # Evaluates symbol (method reference) or proc (responds to call) options
      #
      # If the option is not a symbol or proc then the original option is returned
      def evaluate_yattr_encrypted_option(option)
        if option.is_a?(Symbol) && respond_to?(option)
          send(option)
        elsif option.respond_to?(:call)
          option.call(self)
        else
          option
        end
      end
  end
end

Object.extend YattrEncrypted

Dir[File.join(File.dirname(__FILE__), 'yattr_encrypted', 'adapters', '*.rb')].each { |adapter| require adapter }
