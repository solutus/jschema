require 'minitest/autorun'
require 'webmock/minitest'
require 'jschema'
require 'ostruct'

require_relative 'assert_received'

class TestJSONReference < Minitest::Test
  def test_schema_registration_and_dereferencing
    schema = generate_schema('registered')
    JSchema::JSONReference.register_schema schema
    assert_equal dereference(schema), schema
  end

  def test_schema_dereferencing_with_same_uri
    schema1 = generate_schema('uri')
    schema2 = generate_schema('uri')
    JSchema::JSONReference.register_schema schema1
    JSchema::JSONReference.register_schema schema2

    assert_equal dereference(schema1), schema1
    assert_equal dereference(schema2), schema2
  end

  def test_dereferencing_external_schema
    external_schema = { 'type' => 'number' }
    schema_uri = 'http://example.com/geo'

    expected_schema_args = [external_schema, URI(schema_uri), nil]
    assert_received JSchema::Schema, :new, expected_schema_args do
      JSchema::JSONReference.stub :register_schema, nil do
        dereference_external_schema schema_uri, external_schema.to_json, false
      end
    end
  end

  def test_that_external_schema_is_cached_after_dereferencing
    schema = Object.new
    JSchema::Schema.stub :new, schema do
      assert_received JSchema::JSONReference, :register_schema, [schema] do
        dereference_external_schema 'http://example.com', '{}'
      end
    end
  end

  def test_dereferencing_external_schema_when_it_is_not_valid
    assert_raises(JSchema::InvalidSchema) do
      dereference_external_schema 'http://example.com/', '}'
    end
  end

  def test_dereferencing_external_schema_when_it_is_not_available
    assert_raises(JSchema::InvalidSchema) do
      stub_request(:get, //).to_timeout
      dereference generate_schema('http://example.com/')
    end
  end

  def test_dereferencing_external_schema_when_protocol_is_not_supported
    assert_raises(JSchema::InvalidSchema) do
      dereference_external_schema 'ftp://example.com/', '{}'
    end
  end

  private

  def dereference_external_schema(uri, response_schema, parent = true)
    stub_request(:get, uri).to_return(body: response_schema)
    dereference generate_schema(uri), parent
  end

  def dereference(schema, parent = true)
    parent_schema = parent ? schema : nil
    JSchema::JSONReference.dereference(schema.uri, parent_schema)
  end

  def generate_schema(uri)
    OpenStruct.new(uri: URI(uri), id: generate_id)
  end

  def generate_id
    @id ||= 0
    @id += 1
  end
end
