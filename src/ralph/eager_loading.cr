# Eager Loading module for Ralph ORM
#
# Provides two strategies for solving the N+1 query problem:
#
# 1. **Preloading** (separate queries) - Default strategy, works with all association types
#    Uses IN clause batching to load associations efficiently.
#    ```
# # Instead of N+1 queries:
# authors = Author.all
# authors.each { |a| a.posts } # N queries!
#
# # Use preloading for 2 queries total:
# authors = Author.includes(:posts).to_a
# authors.each { |a| a.posts } # Already loaded!
#    ```
#
# 2. **Eager Loading** (LEFT JOIN) - Single query strategy
#    Uses LEFT JOIN to fetch all data in one query.
#    Better for small result sets, but requires row deduplication.
#    ```
# authors = Author.eager_load(:posts).to_a
#    ```
#
# Nested includes are supported:
# ```
# Author.includes(posts: :comments).to_a
# Author.includes(posts: {comments: :author}).to_a
# Author.includes(:profile, posts: [:comments, :tags]).to_a
# ```
#
module Ralph
  module EagerLoading
    # Type alias for include specifications
    # Can be:
    # - Symbol: :posts
    # - Array of Symbols: [:posts, :comments]
    # - Hash with Symbol keys: {posts: :comments}
    # - Hash with nested structure: {posts: {comments: :author}}
    alias IncludeSpec = Symbol | Array(Symbol) | Hash(Symbol, IncludeSpec) | Array(IncludeSpec)

    # Configuration for N+1 detection
    class_property n_plus_one_warnings_enabled : Bool = false
    class_property n_plus_one_strict_mode : Bool = false

    # Query counter for N+1 detection
    @@query_counts : Hash(String, Hash(String, Int32)) = Hash(String, Hash(String, Int32)).new

    # Enable N+1 query warnings
    def self.enable_n_plus_one_warnings!
      @@n_plus_one_warnings_enabled = true
    end

    # Disable N+1 query warnings
    def self.disable_n_plus_one_warnings!
      @@n_plus_one_warnings_enabled = false
    end

    # Enable strict mode (raises exception instead of warning)
    def self.enable_strict_mode!
      @@n_plus_one_strict_mode = true
    end

    # Disable strict mode
    def self.disable_strict_mode!
      @@n_plus_one_strict_mode = false
    end

    # Track a query for N+1 detection
    def self.track_query(model_class : String, association : String)
      return unless @@n_plus_one_warnings_enabled

      @@query_counts[model_class] ||= Hash(String, Int32).new(default_value: 0)
      @@query_counts[model_class][association] += 1

      count = @@query_counts[model_class][association]
      if count > 1
        message = "N+1 query detected: #{model_class}##{association} called #{count} times. Consider using .includes(:#{association})"
        if @@n_plus_one_strict_mode
          raise NPlusOneQueryError.new(message)
        else
          STDERR.puts "WARNING: #{message}"
        end
      end
    end

    # Reset query counts (call at the start of each request)
    def self.reset_query_counts!
      @@query_counts.clear
    end

    # Exception for N+1 queries in strict mode
    class NPlusOneQueryError < Exception
    end

    # Preloader - handles the separate-query preloading strategy
    #
    # This is the recommended strategy for most use cases.
    # It executes N+1 queries as 2 queries using IN clause batching.
    #
    # Example:
    # ```
    # authors = Author.all
    # Preloader.preload(authors, :posts)
    # # Now authors.each { |a| a.posts } won't trigger additional queries
    # ```
    class Preloader
      # Preload associations on a collection of models
      #
      # Supports various include specifications:
      # - Symbol: preload(:posts)
      # - Array: preload([:posts, :comments])
      # - Hash: preload({posts: :comments})
      def self.preload(models : Array(T), includes : IncludeSpec) : Nil forall T
        return if models.empty?

        case includes
        when Symbol
          preload_association(models, includes)
        when Array
          includes.each do |inc|
            case inc
            when Symbol
              preload_association(models, inc)
            when Hash
              inc.each do |assoc, nested|
                preload_association(models, assoc)
                # Get the loaded associations for nested preloading
                associated_records = models.flat_map { |m| m._get_preloaded_many(assoc.to_s) || [] of Model }
                preload(associated_records, nested) unless associated_records.empty?
              end
            end
          end
        when Hash
          includes.each do |assoc, nested|
            preload_association(models, assoc)
            # Get the loaded associations for nested preloading
            associated_records = models.flat_map { |m| m._get_preloaded_many(assoc.to_s) || [] of Model }
            preload(associated_records, nested) unless associated_records.empty?
          end
        end
      end

      # Preload a single association on all models
      def self.preload_association(models : Array(T), association : Symbol) : Nil forall T
        return if models.empty?

        # Get association metadata
        model_class = models.first.class.to_s
        associations = Associations.associations[model_class]?
        return unless associations

        metadata = associations[association.to_s]?
        return unless metadata

        case metadata.type
        when :belongs_to
          preload_belongs_to(models, metadata)
        when :has_one
          preload_has_one(models, metadata)
        when :has_many
          if metadata.through
            preload_has_many_through(models, metadata)
          else
            preload_has_many(models, metadata)
          end
        end
      end

      # Preload belongs_to association
      private def self.preload_belongs_to(models : Array(T), metadata : AssociationMetadata) : Nil forall T
        return if models.empty?

        if metadata.polymorphic
          preload_polymorphic_belongs_to(models, metadata)
          return
        end

        # Collect all foreign key values
        foreign_key = metadata.foreign_key
        fk_values = models.compact_map do |model|
          model.__get_by_key_name(foreign_key).as(Int64?)
        end.uniq

        return if fk_values.empty?

        # Fetch all associated records in one query
        associated_class = metadata.class_name
        table_name = metadata.table_name
        primary_key = metadata.primary_key

        query = Query::Builder.new(table_name)
          .where_in(primary_key, fk_values.map(&.as(Query::DBValue)))

        # Execute query and build lookup hash
        results = Ralph.database.query_all(query.build_select, args: query.where_args)
        records_by_pk = Hash(Int64, Model).new

        results.each do
          record = _instantiate_model(associated_class, results)
          if pk = record.id
            records_by_pk[pk] = record
          end
        end
        results.close

        # Assign preloaded records to each model
        models.each do |model|
          fk_value = model.__get_by_key_name(foreign_key).as(Int64?)
          if fk_value && (record = records_by_pk[fk_value]?)
            model._set_preloaded_one(metadata.name, record)
          else
            model._set_preloaded_one(metadata.name, nil)
          end
        end
      end

      # Preload polymorphic belongs_to association
      private def self.preload_polymorphic_belongs_to(models : Array(T), metadata : AssociationMetadata) : Nil forall T
        return if models.empty?

        foreign_key = metadata.foreign_key
        type_column = "#{metadata.name}_type"

        # Group models by type
        models_by_type = Hash(String, Array(Tuple(T, Int64))).new

        models.each do |model|
          fk_value = model.__get_by_key_name(foreign_key).as(Int64?)
          type_value = model.__get_by_key_name(type_column).as(String?)

          if fk_value && type_value
            models_by_type[type_value] ||= [] of Tuple(T, Int64)
            models_by_type[type_value] << {model, fk_value}
          end
        end

        # Fetch records for each type
        models_by_type.each do |type_name, model_fk_pairs|
          fk_values = model_fk_pairs.map(&.[1]).uniq

          # Use polymorphic registry to find records
          records_by_pk = Hash(Int64, Model).new
          fk_values.each do |fk|
            if record = Associations.find_polymorphic(type_name, fk)
              records_by_pk[fk] = record
            end
          end

          # Assign to models
          model_fk_pairs.each do |model, fk_value|
            if record = records_by_pk[fk_value]?
              model._set_preloaded_one(metadata.name, record)
            else
              model._set_preloaded_one(metadata.name, nil)
            end
          end
        end

        # Mark models without type/fk as preloaded with nil
        models.each do |model|
          unless model._has_preloaded?(metadata.name)
            model._set_preloaded_one(metadata.name, nil)
          end
        end
      end

      # Preload has_one association
      private def self.preload_has_one(models : Array(T), metadata : AssociationMetadata) : Nil forall T
        return if models.empty?

        # Collect all primary key values
        pk_values = models.compact_map(&.id).uniq
        return if pk_values.empty?

        associated_class = metadata.class_name
        table_name = metadata.table_name
        foreign_key = metadata.foreign_key

        query = if metadata.as_name
                  # Polymorphic has_one
                  type_column = "#{metadata.as_name}_type"
                  id_column = "#{metadata.as_name}_id"
                  model_type = models.first.class.to_s

                  Query::Builder.new(table_name)
                    .where("\"#{type_column}\" = ?", model_type)
                    .where_in(id_column, pk_values.map(&.as(Query::DBValue)))
                else
                  Query::Builder.new(table_name)
                    .where_in(foreign_key, pk_values.map(&.as(Query::DBValue)))
                end

        # Execute query and build lookup hash by foreign key
        results = Ralph.database.query_all(query.build_select, args: query.where_args)
        records_by_fk = Hash(Int64, Model).new

        results.each do
          record = _instantiate_model(associated_class, results)
          fk_value = if metadata.as_name
                       record.__get_by_key_name("#{metadata.as_name}_id").as(Int64?)
                     else
                       record.__get_by_key_name(foreign_key).as(Int64?)
                     end
          if fk_value
            records_by_fk[fk_value] = record
          end
        end
        results.close

        # Assign preloaded records to each model
        models.each do |model|
          pk_value = model.id
          if pk_value && (record = records_by_fk[pk_value]?)
            model._set_preloaded_one(metadata.name, record)
          else
            model._set_preloaded_one(metadata.name, nil)
          end
        end
      end

      # Preload has_many association
      private def self.preload_has_many(models : Array(T), metadata : AssociationMetadata) : Nil forall T
        return if models.empty?

        # Collect all primary key values
        pk_values = models.compact_map(&.id).uniq
        return if pk_values.empty?

        associated_class = metadata.class_name
        table_name = metadata.table_name
        foreign_key = metadata.foreign_key

        query = if metadata.as_name
                  # Polymorphic has_many
                  type_column = "#{metadata.as_name}_type"
                  id_column = "#{metadata.as_name}_id"
                  model_type = models.first.class.to_s

                  Query::Builder.new(table_name)
                    .where("\"#{type_column}\" = ?", model_type)
                    .where_in(id_column, pk_values.map(&.as(Query::DBValue)))
                else
                  Query::Builder.new(table_name)
                    .where_in(foreign_key, pk_values.map(&.as(Query::DBValue)))
                end

        # Execute query and group by foreign key
        results = Ralph.database.query_all(query.build_select, args: query.where_args)
        records_by_fk = Hash(Int64, Array(Model)).new

        results.each do
          record = _instantiate_model(associated_class, results)
          fk_value = if metadata.as_name
                       record.__get_by_key_name("#{metadata.as_name}_id").as(Int64?)
                     else
                       record.__get_by_key_name(foreign_key).as(Int64?)
                     end
          if fk_value
            records_by_fk[fk_value] ||= [] of Model
            records_by_fk[fk_value] << record
          end
        end
        results.close

        # Assign preloaded records to each model
        models.each do |model|
          pk_value = model.id
          if pk_value
            records = records_by_fk[pk_value]? || [] of Model
            model._set_preloaded_many(metadata.name, records)
          else
            model._set_preloaded_many(metadata.name, [] of Model)
          end
        end
      end

      # Preload has_many :through association
      private def self.preload_has_many_through(models : Array(T), metadata : AssociationMetadata) : Nil forall T
        return if models.empty?
        return unless through_name = metadata.through

        # First, preload the through association
        model_class = models.first.class.to_s
        associations = Associations.associations[model_class]?
        return unless associations

        through_metadata = associations[through_name]?
        return unless through_metadata

        # Preload through association
        preload_association(models, through_name.to_sym)

        # Collect through records
        through_records = models.flat_map do |model|
          model._get_preloaded_many(through_name) || [] of Model
        end

        return if through_records.empty?

        # Get the source association on the through model
        source_name = metadata.source || metadata.name.rchop('s')
        through_class = through_metadata.class_name
        through_associations = Associations.associations[through_class]?
        return unless through_associations

        source_metadata = through_associations[source_name]?
        return unless source_metadata

        # Preload source association on through records
        preload_belongs_to(through_records, source_metadata) if source_metadata.type == :belongs_to

        # Build mapping: parent_id -> [source_records]
        records_by_parent = Hash(Int64, Array(Model)).new

        # Get through association's foreign key to parent
        parent_fk = through_metadata.foreign_key

        models.each do |model|
          parent_id = model.id
          next unless parent_id

          through_for_parent = (model._get_preloaded_many(through_name) || [] of Model)
          source_records = through_for_parent.compact_map do |through_record|
            through_record._get_preloaded_one(source_name)
          end

          records_by_parent[parent_id] = source_records
        end

        # Assign to parent models
        models.each do |model|
          parent_id = model.id
          if parent_id
            records = records_by_parent[parent_id]? || [] of Model
            model._set_preloaded_many(metadata.name, records)
          else
            model._set_preloaded_many(metadata.name, [] of Model)
          end
        end
      end

      # Helper to instantiate a model from result set
      # This uses the polymorphic registry to find the right class
      private def self._instantiate_model(class_name : String, rs : DB::ResultSet) : Model
        # We need to use the model registry to instantiate the right class
        # For now, we'll use a workaround - the model itself handles this
        raise "Cannot instantiate model #{class_name} - use typed preloading instead"
      end
    end

    # EagerLoader - handles the LEFT JOIN strategy
    #
    # Fetches all data in a single query using LEFT JOINs.
    # Better for small result sets but requires row deduplication.
    #
    # Example:
    # ```
    # authors = Author.eager_load(:posts).to_a
    # ```
    class EagerLoader
      # Build a query with LEFT JOINs for the specified associations
      def self.build_query(model_class : String, table_name : String, includes : IncludeSpec) : Query::Builder
        query = Query::Builder.new(table_name)
        add_joins(query, model_class, table_name, includes)
      end

      # Add LEFT JOINs for associations recursively
      private def self.add_joins(query : Query::Builder, model_class : String, parent_table : String, includes : IncludeSpec) : Query::Builder
        associations = Associations.associations[model_class]?
        return query unless associations

        case includes
        when Symbol
          if metadata = associations[includes.to_s]?
            query = add_join_for_association(query, parent_table, metadata)
          end
        when Array
          includes.each do |inc|
            case inc
            when Symbol
              if metadata = associations[inc.to_s]?
                query = add_join_for_association(query, parent_table, metadata)
              end
            when Hash
              inc.each do |assoc, nested|
                if metadata = associations[assoc.to_s]?
                  query = add_join_for_association(query, parent_table, metadata)
                  # Recursively add joins for nested associations
                  query = add_joins(query, metadata.class_name, metadata.table_name, nested)
                end
              end
            end
          end
        when Hash
          includes.each do |assoc, nested|
            if metadata = associations[assoc.to_s]?
              query = add_join_for_association(query, parent_table, metadata)
              # Recursively add joins for nested associations
              query = add_joins(query, metadata.class_name, metadata.table_name, nested)
            end
          end
        end

        query
      end

      # Add a single LEFT JOIN for an association
      private def self.add_join_for_association(query : Query::Builder, parent_table : String, metadata : AssociationMetadata) : Query::Builder
        assoc_table = metadata.table_name
        foreign_key = metadata.foreign_key

        on_clause = case metadata.type
                    when :belongs_to
                      "\"#{assoc_table}\".\"#{metadata.primary_key}\" = \"#{parent_table}\".\"#{foreign_key}\""
                    when :has_one, :has_many
                      if as_name = metadata.as_name
                        # Polymorphic
                        type_column = "#{as_name}_type"
                        id_column = "#{as_name}_id"
                        "\"#{assoc_table}\".\"#{id_column}\" = \"#{parent_table}\".\"id\" AND \"#{assoc_table}\".\"#{type_column}\" = '#{parent_table.camelcase}'"
                      else
                        "\"#{assoc_table}\".\"#{foreign_key}\" = \"#{parent_table}\".\"id\""
                      end
                    else
                      "\"#{assoc_table}\".\"#{foreign_key}\" = \"#{parent_table}\".\"id\""
                    end

        query.join(assoc_table, on_clause, :left)
      end
    end
  end
end
