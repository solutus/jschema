module JSchema
  class Schema
    VERSION_ID = 'http://json-schema.org/draft-04/schema#'.freeze

    class << self
      def build(sch = {}, parent = nil, id = nil)
        schema = sch || {}

        check_schema_version schema

        if (json_reference = schema['$ref'])
          unescaped_ref = json_reference.gsub(/~1|~0/, '~1' => '/', '~0' => '~')
          SchemaRef.new(URI(unescaped_ref), parent)
        else
          uri = SchemaURI.build(schema['id'], parent, id)
          parent && JSONReference.dereference(uri, parent) || begin
            jschema = new(schema, uri, parent)
            register_definitions schema, jschema
            JSONReference.register_schema jschema
          end
        end
      end

      private

      def check_schema_version(schema)
        version = schema['$schema']
        if version && version != VERSION_ID
          fail InvalidSchema, 'Specified schema version is not supported'
        end
      end

      def register_definitions(schema, parent)
        if (definitions = schema['definitions'])
          definitions.each do |definition, sch|
            schema_def = build(sch, parent, "definitions/#{definition}")
            JSONReference.register_schema schema_def
          end
        end
      end
    end

    attr_reader :uri, :parent

    def valid?(instance)
      validate(instance).empty?
    end

    def validate(instance)
      @validators.map do |validator|
        validator.validate(instance)
      end.compact
    end

    def to_s
      uri.to_s
    end

    private

    def initialize(schema, uri, parent)
      @uri = uri
      @parent = parent
      @validators = Validator.build(schema, self)
    end
  end
end
