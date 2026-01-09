# Association Inferrer for db:pull
#
# Infers Ralph associations from database foreign key relationships.
# Used to generate belongs_to, has_many, and has_one associations
# when pulling models from an existing database schema.

module Ralph
  module Cli
    # Represents an inferred association from foreign key analysis
    struct InferredAssociation
      # Association type (:belongs_to, :has_many, :has_one)
      property type : Symbol
      # Association name (e.g., "user", "posts")
      property name : String
      # Target class name (e.g., "User", "Post")
      property class_name : String
      # Foreign key column (nil if convention matches)
      property foreign_key : String?
      # Whether this is a polymorphic association
      property polymorphic : Bool
      # Polymorphic name (for polymorphic associations)
      property polymorphic_name : String?
      # Whether the association is optional (FK is nullable)
      property optional : Bool

      def initialize(
        @type : Symbol,
        @name : String,
        @class_name : String,
        @foreign_key : String? = nil,
        @polymorphic : Bool = false,
        @polymorphic_name : String? = nil,
        @optional : Bool = false,
      )
      end

      # Generate the Ralph association macro call
      def to_macro_call : String
        case @type
        when :belongs_to
          generate_belongs_to
        when :has_many
          generate_has_many
        when :has_one
          generate_has_one
        else
          "# Unknown association type: #{@type}"
        end
      end

      private def generate_belongs_to : String
        if @polymorphic
          "belongs_to #{@name}, polymorphic: true"
        else
          parts = ["belongs_to #{@name} : #{@class_name}"]
          parts << ", foreign_key: :#{@foreign_key}" if @foreign_key
          parts << ", optional: true" if @optional
          parts.join
        end
      end

      private def generate_has_many : String
        parts = ["has_many #{@name} : #{@class_name}"]
        parts << ", foreign_key: :#{@foreign_key}" if @foreign_key
        parts.join
      end

      private def generate_has_one : String
        parts = ["has_one #{@name} : #{@class_name}"]
        parts << ", foreign_key: :#{@foreign_key}" if @foreign_key
        parts.join
      end
    end

    # Infers associations from database schema foreign keys
    class AssociationInferrer
      @schema : Schema::DatabaseSchema
      @fk_index : Hash(String, Array(Schema::DatabaseForeignKey))

      def initialize(@schema : Schema::DatabaseSchema)
        @fk_index = build_fk_index
      end

      # Infer all associations for a table
      def infer_for(table : Schema::DatabaseTable) : Array(InferredAssociation)
        associations = [] of InferredAssociation

        # 1. belongs_to from outgoing foreign keys
        table.foreign_keys.each do |fk|
          associations << infer_belongs_to(table, fk)
        end

        # 2. Detect polymorphic belongs_to from column patterns
        polymorphic = detect_polymorphic_belongs_to(table)
        associations.concat(polymorphic)

        # 3. has_many/has_one from incoming foreign keys
        incoming_fks = @fk_index[table.name]? || [] of Schema::DatabaseForeignKey
        incoming_fks.each do |fk|
          # Only infer has_many/has_one for FKs that follow naming convention
          # (e.g., user_id -> users, not deleted_by_user_id -> users)
          expected_fk = "#{table.name.singularize}_id"
          next unless fk.from_column == expected_fk

          # Determine if it should be has_one or has_many
          if should_be_has_one?(fk)
            associations << infer_has_one(table, fk)
          else
            associations << infer_has_many(table, fk)
          end
        end

        associations
      end

      private def build_fk_index : Hash(String, Array(Schema::DatabaseForeignKey))
        index = Hash(String, Array(Schema::DatabaseForeignKey)).new

        # Index all foreign keys by their target table
        @schema.each_table do |table|
          table.foreign_keys.each do |fk|
            target = fk.to_table
            index[target] ||= [] of Schema::DatabaseForeignKey
            index[target] << fk
          end
        end

        index
      end

      private def infer_belongs_to(table : Schema::DatabaseTable, fk : Schema::DatabaseForeignKey) : InferredAssociation
        # Association name from FK column: avatar_file_id -> avatar_file
        assoc_name = fk.from_column.chomp("_id")
        # Class name from target table: files -> File
        class_name = classify(fk.to_table)

        # Check if foreign key follows convention (assoc_name_id == column_name)
        standard_fk = "#{assoc_name}_id"
        foreign_key = (fk.from_column == standard_fk) ? nil : fk.from_column

        # Check if FK column is nullable
        fk_column = table.column(fk.from_column)
        optional = fk_column.try(&.nullable) || false

        InferredAssociation.new(
          type: :belongs_to,
          name: assoc_name,
          class_name: class_name,
          foreign_key: foreign_key,
          polymorphic: false,
          optional: optional
        )
      end

      private def detect_polymorphic_belongs_to(table : Schema::DatabaseTable) : Array(InferredAssociation)
        associations = [] of InferredAssociation

        # Look for _id + _type column pairs that aren't covered by FKs
        type_columns = table.columns.select { |c| c.name.ends_with?("_type") }

        type_columns.each do |type_col|
          base_name = type_col.name.chomp("_type")
          id_col_name = "#{base_name}_id"

          # Check if the id column exists
          id_col = table.column(id_col_name)
          next unless id_col

          # Check if this is already covered by a regular FK
          # (If there's an FK on the _id column, it's not polymorphic)
          already_has_fk = table.foreign_keys.any? { |fk| fk.from_column == id_col_name }
          next if already_has_fk

          # This looks like a polymorphic association
          optional = id_col.nullable

          associations << InferredAssociation.new(
            type: :belongs_to,
            name: base_name,
            class_name: "Ralph::Model", # Polymorphic, actual type determined at runtime
            foreign_key: nil,
            polymorphic: true,
            polymorphic_name: base_name,
            optional: optional
          )
        end

        associations
      end

      private def infer_has_many(table : Schema::DatabaseTable, fk : Schema::DatabaseForeignKey) : InferredAssociation
        # posts has_many comments (from comments.post_id -> posts.id)
        from_table_singular = fk.from_table.singularize
        assoc_name = from_table_singular.pluralize
        class_name = classify(from_table_singular)

        # Check if foreign key follows convention
        expected_fk = "#{table.name.singularize}_id"
        foreign_key = (fk.from_column == expected_fk) ? nil : fk.from_column

        InferredAssociation.new(
          type: :has_many,
          name: assoc_name,
          class_name: class_name,
          foreign_key: foreign_key
        )
      end

      private def infer_has_one(table : Schema::DatabaseTable, fk : Schema::DatabaseForeignKey) : InferredAssociation
        # user has_one profile (from profiles.user_id -> users.id with unique constraint)
        from_table_singular = fk.from_table.singularize
        assoc_name = from_table_singular
        class_name = classify(from_table_singular)

        # Check if foreign key follows convention
        expected_fk = "#{table.name.singularize}_id"
        foreign_key = (fk.from_column == expected_fk) ? nil : fk.from_column

        InferredAssociation.new(
          type: :has_one,
          name: assoc_name,
          class_name: class_name,
          foreign_key: foreign_key
        )
      end

      private def should_be_has_one?(fk : Schema::DatabaseForeignKey) : Bool
        # Heuristics for has_one vs has_many:
        # 1. FK column has unique index
        # 2. Table name suggests 1:1 (e.g., "user_profile", "account_settings")
        # 3. FK column is also the primary key (1:1 via PK)

        from_table = @schema.table(fk.from_table)
        return false unless from_table

        # Check for unique constraint on FK column
        has_unique_index = from_table.indexes.any? do |idx|
          idx.unique && idx.columns.size == 1 && idx.columns.first == fk.from_column
        end

        return true if has_unique_index

        # Check if FK column is primary key
        is_pk = from_table.primary_key_columns.size == 1 &&
                from_table.primary_key_columns.first == fk.from_column

        return true if is_pk

        # Check table name patterns that suggest 1:1
        singular_table = from_table.name.singularize
        one_to_one_patterns = ["_profile", "_settings", "_details", "_info", "_meta"]
        one_to_one_patterns.any? { |pattern| singular_table.ends_with?(pattern) }
      end

      # Convert table name to class name (e.g., "users" -> "User", "user_profiles" -> "UserProfile")
      private def classify(name : String) : String
        name.singularize.split('_').map(&.capitalize).join
      end
    end
  end
end
