require File.expand_path('../test_helper', __FILE__)

class User
  self.yattr_encrypted_options[:key] = Proc.new { |user| user.class.to_s } # default key

  yattr_encrypted :email, :without_encoding, :key => 'secret key'
  yattr_encrypted :password, :prefix => 'crypted_', :suffix => '_test'
  yattr_encrypted :ssn, :key => :salt, :attribute => 'ssn_encrypted'
  yattr_encrypted :credit_card, :encryptor => SillyEncryptor, :encrypt_method => :silly_encrypt, :decrypt_method => :silly_decrypt, :some_arg => 'test'
  yattr_encrypted :with_encoding, :key => 'secret key', :encode => true
  yattr_encrypted :with_custom_encoding, :key => 'secret key', :encode => 'm'
  yattr_encrypted :with_marshaling, :key => 'secret key', :marshal => true
  yattr_encrypted :with_true_if, :key => 'secret key', :if => true
  yattr_encrypted :with_false_if, :key => 'secret key', :if => false
  yattr_encrypted :with_true_unless, :key => 'secret key', :unless => true
  yattr_encrypted :with_false_unless, :key => 'secret key', :unless => false
  yattr_encrypted :with_if_changed, :key => 'secret key', :if => :should_encrypt
  yattr_encrypted :with_dynamic_iv, :key => 'a very long, very long, even longer secret key' ,
      :iv => lambda { |arg| (0..16).map { |x| rand(256).chr }.join() }

  attr_encryptor :aliased, :key => 'secret_key'

  attr_accessor :salt
  attr_accessor :should_encrypt

  def initialize
    self.salt = Time.now.to_i.to_s
    self.should_encrypt = true
  end
end

class Admin < User
  yattr_encrypted :testing
end

class SomeOtherClass
  def self.call(object)
    object.class
  end
end

class YattrEncryptedTest < Test::Unit::TestCase

  def test_should_store_email_in_encrypted_attributes
    assert User.encrypted_attributes.include?(:email)
  end

  def test_should_not_store_salt_in_encrypted_attributes
    assert !User.encrypted_attributes.include?(:salt)
  end

  def test_yattr_encrypted_should_return_true_for_email
    assert User.yattr_encrypted?('email')
  end

  def test_yattr_encrypted_should_not_use_the_same_attribute_name_for_two_attributes_in_the_same_line
    assert_not_equal User.encrypted_attributes[:email][:attribute], User.encrypted_attributes[:without_encoding][:attribute]
  end

  def test_yattr_encrypted_should_return_false_for_salt
    assert !User.yattr_encrypted?('salt')
  end

  def test_should_generate_an_encrypted_attribute
    assert User.new.respond_to?(:encrypted_email)
  end

  def test_should_generate_an_encrypted_attribute_with_a_prefix_and_suffix
    assert User.new.respond_to?(:crypted_password_test)
  end

  def test_should_generate_an_encrypted_attribute_with_the_attribute_option
    assert User.new.respond_to?(:ssn_encrypted)
  end

  def test_should_not_encrypt_nil_value
    assert_nil User.encrypt_email(nil)
  end

  def test_should_not_encrypt_empty_string
    assert_equal '', User.encrypt_email('')
  end

  def test_should_encrypt_email
    assert_not_nil User.encrypt_email('test@example.com')
    assert_not_equal 'test@example.com', User.encrypt_email('test@example.com')
  end

  def test_should_encrypt_email_when_modifying_the_attr_writer
    @user = User.new
    assert_nil @user.encrypted_email
    @user.email = 'test@example.com'
    assert_not_nil @user.encrypted_email
    assert_equal User.encrypt_email('test@example.com'), @user.encrypted_email
  end

  def test_should_not_decrypt_nil_value
    assert_nil User.decrypt_email(nil)
  end

  def test_should_not_decrypt_empty_string
    assert_equal '', User.decrypt_email('')
  end

  def test_should_decrypt_email
    encrypted_email = User.encrypt_email('test@example.com')
    assert_not_equal 'test@test.com', encrypted_email
    assert_equal 'test@example.com', User.decrypt_email(encrypted_email)
  end

  def test_should_decrypt_email_when_reading
    @user = User.new
    assert_nil @user.email
    @user.encrypted_email = User.encrypt_email('test@example.com')
    assert_equal 'test@example.com', @user.email
  end

  def test_should_encrypt_with_encoding
    assert_equal User.encrypt_with_encoding('test'), [User.encrypt_without_encoding('test')].pack('m')
  end

  def test_should_decrypt_with_encoding
    encrypted = User.encrypt_with_encoding('test')
    assert_equal 'test', User.decrypt_with_encoding(encrypted)
    assert_equal User.decrypt_with_encoding(encrypted), User.decrypt_without_encoding(encrypted.unpack('m').first)
  end

  def test_should_encrypt_with_custom_encoding
    assert_equal User.encrypt_with_encoding('test'), [User.encrypt_without_encoding('test')].pack('m')
  end

  def test_should_decrypt_with_custom_encoding
    encrypted = User.encrypt_with_encoding('test')
    assert_equal 'test', User.decrypt_with_encoding(encrypted)
    assert_equal User.decrypt_with_encoding(encrypted), User.decrypt_without_encoding(encrypted.unpack('m').first)
  end

  def test_should_encrypt_with_marshaling
    @user = User.new
    @user.with_marshaling = [1, 2, 3]
    assert_not_nil @user.encrypted_with_marshaling
    assert_equal User.encrypt_with_marshaling([1, 2, 3]), @user.encrypted_with_marshaling
  end

  def test_should_decrypt_with_marshaling
    encrypted = User.encrypt_with_marshaling([1, 2, 3])
    @user = User.new
    assert_nil @user.with_marshaling
    @user.encrypted_with_marshaling = encrypted
    assert_equal [1, 2, 3], @user.with_marshaling
  end

  def test_should_use_custom_encryptor_and_crypt_method_names_and_arguments
    assert_equal SillyEncryptor.silly_encrypt(:value => 'testing', :some_arg => 'test'), User.encrypt_credit_card('testing')
  end

  def test_should_evaluate_a_key_passed_as_a_symbol
    @user = User.new
    assert_nil @user.ssn_encrypted
    @user.ssn = 'testing'
    assert_not_nil @user.ssn_encrypted
    assert_equal Encryptor.encrypt(:value => 'testing', :key => @user.salt), @user.ssn_encrypted
  end

  def test_should_evaluate_a_key_passed_as_a_proc
    @user = User.new
    assert_nil @user.crypted_password_test
    @user.password = 'testing'
    assert_not_nil @user.crypted_password_test
    assert_equal Encryptor.encrypt(:value => 'testing', :key => 'User'), @user.crypted_password_test
  end

  def test_should_use_options_found_in_the_yattr_encrypted_options_attribute
    @user = User.new
    assert_nil @user.crypted_password_test
    @user.password = 'testing'
    assert_not_nil @user.crypted_password_test
    assert_equal Encryptor.encrypt(:value => 'testing', :key => 'User'), @user.crypted_password_test
  end

  def test_should_inherit_encrypted_attributes
    assert_equal [User.encrypted_attributes.keys, :testing].flatten.collect { |key| key.to_s }.sort, Admin.encrypted_attributes.keys.collect { |key| key.to_s }.sort
  end

  def test_should_inherit_yattr_encrypted_options
    assert !User.yattr_encrypted_options.empty?
    assert_equal User.yattr_encrypted_options, Admin.yattr_encrypted_options
  end

  def test_should_not_inherit_unrelated_attributes
    assert SomeOtherClass.yattr_encrypted_options.empty?
    assert SomeOtherClass.encrypted_attributes.empty?
  end

  def test_should_evaluate_a_symbol_option
    assert_equal Object, Object.new.send(:evaluate_yattr_encrypted_option, :class)
  end

  def test_should_evaluate_a_proc_option
    assert_equal Object, Object.new.send(:evaluate_yattr_encrypted_option, proc { |object| object.class })
  end

  def test_should_evaluate_a_lambda_option
    assert_equal Object, Object.new.send(:evaluate_yattr_encrypted_option, lambda { |object| object.class })
  end

  def test_should_evaluate_a_method_option
    assert_equal Object, Object.new.send(:evaluate_yattr_encrypted_option, SomeOtherClass.method(:call))
  end

  def test_should_return_a_string_option
    assert_equal 'Object', Object.new.send(:evaluate_yattr_encrypted_option, 'Object')
  end

  def test_should_encrypt_with_true_if
    @user = User.new
    assert_nil @user.encrypted_with_true_if
    @user.with_true_if = 'testing'
    assert_not_nil @user.encrypted_with_true_if
    assert_equal Encryptor.encrypt(:value => 'testing', :key => 'secret key'), @user.encrypted_with_true_if
  end

  def test_should_not_encrypt_with_false_if
    @user = User.new
    assert_nil @user.encrypted_with_false_if
    @user.with_false_if = 'testing'
    assert_not_nil @user.encrypted_with_false_if
    assert_equal 'testing', @user.encrypted_with_false_if
  end

  def test_should_encrypt_with_false_unless
    @user = User.new
    assert_nil @user.encrypted_with_false_unless
    @user.with_false_unless = 'testing'
    assert_not_nil @user.encrypted_with_false_unless
    assert_equal Encryptor.encrypt(:value => 'testing', :key => 'secret key'), @user.encrypted_with_false_unless
  end

  def test_should_not_encrypt_with_true_unless
    @user = User.new
    assert_nil @user.encrypted_with_true_unless
    @user.with_true_unless = 'testing'
    assert_not_nil @user.encrypted_with_true_unless
    assert_equal 'testing', @user.encrypted_with_true_unless
  end

  def test_should_work_with_aliased_attr_encryptor
    assert User.encrypted_attributes.include?(:aliased)
  end

  def test_should_always_reset_options
    @user = User.new
    @user.with_if_changed = "encrypt_stuff"
    @user.stubs(:instance_variable_get).returns(nil)
    @user.stubs(:instance_variable_set).raises("BadStuff")
    assert_raise RuntimeError do 
      @user.with_if_changed
    end

    @user = User.new
    @user.should_encrypt = false
    @user.with_if_changed = "not_encrypted_stuff"
    assert_equal "not_encrypted_stuff", @user.with_if_changed
    assert_equal "not_encrypted_stuff", @user.encrypted_with_if_changed
  end

  def test_should_cast_values_as_strings_before_encrypting
    string_encrypted_email = User.encrypt_email('3')
    assert_equal string_encrypted_email, User.encrypt_email(3)
    assert_equal '3', User.decrypt_email(string_encrypted_email)
  end

  def test_should_create_query_accessor
    @user = User.new
    assert !@user.email?
    @user.email = ''
    assert !@user.email?
    @user.email = 'test@example.com'
    assert @user.email?
  end

  def test_dynamic_iv_should_work
    @user = User.new
    @user.with_dynamic_iv = "this is a string"
    assert_not_nil @user.encrypted_with_dynamic_iv, "encrypted_with_dynamic_iv should not be nil"
    assert_equal "this is a string", @user.with_dynamic_iv, "@user.with_dynamic_iv should recover original data"
    saved_encrypted_value = @user.encrypted_with_dynamic_iv
    @user.with_dynamic_iv = "this is a string"
    assert_not_equal saved_encrypted_value, @user.encrypted_with_dynamic_iv, "newly encrypted value should not be the same as the saved one"
  end
end