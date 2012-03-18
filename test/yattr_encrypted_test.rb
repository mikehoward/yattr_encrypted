require File.expand_path('../test_helper', __FILE__)

# require 'active_record'
require 'yattr_encrypted'

module ActiveRecord
  class Base
    include YattrEncrypted

    def save
    end
    
    def save!
    end
    
    def update_attribute attribute, value
    end
    
    def update_attributes attribute_hash, options
    end
  end
end

class SomeClass < ActiveRecord::Base
  attr_accessor :field_encrypted
  yattr_encrypted :field, :key => 'a honkin big key: honk honk honk honk honk'
end

class TestYattrEncrypted < MiniTest::Unit::TestCase
  def setup
    @sc = SomeClass.new
  end
  
  def test_yattr_encrypted_should_create_accessors
    assert @sc.respond_to?(:field), "a SomeClass instance should respond to :field"
    assert @sc.respond_to?(:field=), "a SomeClass instance should respond to :field="
    assert @sc.respond_to?(:field?), "a SomeClass instance should respond to :field?"
    assert @sc.respond_to?(:yate_encrypted_attributes), "a SomeClass instance should respond to :yate_encrypted_attributes"
  end
  
  def test_assigning_field_should_assign_field_encrypted
    assert_nil @sc.field_encrypted, "field_encrypted should be nil prior to assignment to field"
    @sc.field = 'a field value'
    refute_nil @sc.field_encrypted, "field_encrypted should not be nil"
    assert_equal 'a field value', @sc.field, "@sc.field should match input"
    options = @sc.yate_encrypted_attributes[:field]
pry binding
    assert_equal 'a field value', @sc.send(:yate_decrypt, @sc.field_encrypted, options[:key]), \
      "decrypting @sc.field_encrypted should match input"
  end
  
  def test_save_should_update_encrypted
    @sc.field = { key: 'value' }
pry binding
  end
end
