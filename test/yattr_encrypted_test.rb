require File.expand_path('../test_helper', __FILE__)

# require 'active_record'
require 'yattr_encrypted'

module ActiveRecord
  class Base
    include YattrEncrypted

    def save
    end
  end
end

class SomeClass < ActiveRecord::Base
  attr_accessor :field_encrypted
  yattr_encrypted :field
end

class TestYattrEncrypted < MiniTest::Unit::TestCase
  
  def test_yattr_encrypted_should_create_accessors
    c = SomeClass.new
    assert c.respond_to?(:field), "SomeClass should respond to :field"
    assert c.respond_to?(:field=), "SomeClass should respond to :field="
    assert c.respond_to?(:field?), "SomeClass should respond to :field?"
  end
end
