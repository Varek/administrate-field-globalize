require "rails"
require "administrate/field/globalize/string"
require "administrate/field/globalize/text"

module Administrate
  module Field
    module Globalize
      class Engine < ::Rails::Engine
        initializer "administrate-field-globalize.patch", before: :load_config_initializers do |app|
          Administrate::Field::Base.class_eval do
            def self.translation?
              false
            end
          end

          Administrate::Field::Deferred.class_eval do
            def translation?
              options.fetch(:translation, deferred_class.translation?)
            end
          end

          Administrate::Search.class_eval do
            def run
              if query.blank?
                @scoped_resource.all
              else
                results = search_results(@scoped_resource)
                results = filter_results(results)
                results.distinct
              end
            end

            def tables_to_join
              attribute_types.keys.select do |attribute|
                attribute_types[attribute].searchable? && association_search?(attribute)
              end + translation_join
            end

            def translation_join
              return [] unless attribute_types.values.any? do |field|
                field.respond_to?(:translation?) && field.translation?
              end
              [:translations]
            end

            def query_table_name(attr)
              if attribute_types[attr].respond_to?(:translation?)
                ActiveRecord::Base.connection.
                  quote_table_name(
                    "#{@scoped_resource.table_name.singularize}_translations",
                )
              elsif association_search?(attr)
                provided_class_name = attribute_types[attr].options[:class_name]
                if provided_class_name
                  provided_class_name.constantize.table_name
                else
                  ActiveRecord::Base.connection.quote_table_name(attr.to_s.pluralize)
                end
              else
                ActiveRecord::Base.connection.
                  quote_table_name(@scoped_resource.table_name)
              end
            end
          end
        end
      end
    end
  end
end
