require File.expand_path('../test_helper', __FILE__)

# require 'active_record'
require 'yattr_encrypted'

module ActiveRecord
  class Base
    include YattrEncrypted

    def self.attribute_methods_generated?
      true
    end
    
    def self.before_save *methods
      @before_save_hooks ||= []
      @before_save_hooks += methods
    end

    def save
      true
    end
    
    def save!
      true
    end
    
    def update_attribute attribute, value
      true
    end
    
    def update_attributes attribute_hash, options
      true
    end
  end
end

class SomeClass < ActiveRecord::Base
  attr_accessor :field_encrypted, :special_reader_encrypted, :special_writer_encrypted,
    :method_filtered_encrypted
  yattr_encrypted :field, :key => 'a honkin big key: honk honk honk honk honk'
  yattr_encrypted :special_reader, :key => 'a honkin big key: honk honk honk honk honk',
    :read_filter => lambda { |val| val.strip }
  yattr_encrypted :special_writer, :key => 'a honkin big key: honk honk honk honk honk',
    :write_filter => lambda { |val| val.upcase }
  yattr_encrypted :method_filtered, :key => 'a honkin big key: honk honk honk honk honk',
    :read_filter => 'foo'
  
  def foo attr
    'foo filtered'
  end
end

class TestYattrEncrypted < MiniTest::Unit::TestCase
  def setup
    @sc = SomeClass.new
  end
  
  def test_before_save_hook
    assert SomeClass.instance_variable_get(:@before_save_hooks).include?(:yate_update_encrypted_values), \
        "before_save_hooks should include :yate_encrypted_attributes"
  end

  def test_yattr_encrypted_should_create_accessors
    assert @sc.respond_to?(:field), "a SomeClass instance should respond to :field"
    assert @sc.respond_to?(:field=), "a SomeClass instance should respond to :field="
    assert @sc.respond_to?(:field?), "a SomeClass instance should respond to :field?"
    assert @sc.respond_to?(:yate_encrypted_attributes), "a SomeClass instance should respond to :yate_encrypted_attributes"
  end
  
  def test_assigning_attribute_should_assign_attribute_encrypted
    assert_nil @sc.field_encrypted, "field_encrypted should be nil prior to assignment to field"
    @sc.field = 'a field value'
    refute_nil @sc.field_encrypted, "field_encrypted should not be nil"
    assert_equal 'a field value', @sc.field, "@sc.field should match input"
    options = @sc.send(:yate_encrypted_attributes)[:field]
    assert_equal 'a field value', @sc.send(:yate_decrypt, @sc.field_encrypted, options[:key]), \
      "decrypting @sc.field_encrypted should match input"
  end
  
  def test_save_should_update_encrypted
    @sc.field = { key: 'value' }
    @sc.save
    options = @sc.send(:yate_encrypted_attributes)[:field]
    decrypted = @sc.send(:yate_decrypt, @sc.field_encrypted, options[:key])
    assert_equal( { key: 'value' }, decrypted, "decrypt @sc.field_encrypted should be correct")
  end
  
  def test_special_reader
    value = 'a string with leading and trailing white space'
    value_with_whitespace = '    ' + value + '   '
    @sc.special_reader = value_with_whitespace
    assert_equal value_with_whitespace, @sc.instance_variable_get(:@special_reader),
        "@special_reader should include the leading and trailing whitespace"
    assert_equal value, @sc.special_reader, "@sc.special_reader should have leading and trailing ws stripped"
  end
  
  def test_special_writer
    value = 'a string with leading and trailing white space'
    @sc.special_writer = value
    assert_equal value.upcase, @sc.instance_variable_get(:@special_writer),
      "@special_writer should be upcased"
    assert_equal value.upcase, @sc.special_writer, "@sc.special_writer should be upcased"
  end
  
  def test_method_filtered
    value = 'a string with leading and trailing white space'
    @sc.method_filtered = value
    assert_equal value, @sc.instance_variable_get(:@method_filtered),
      "@method_filtered should be '#{value}'"
    assert_equal 'foo filtered', @sc.method_filtered, "@sc.method_filtered should be 'foo filtered"
  end
end
