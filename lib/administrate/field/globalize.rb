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
              tables = []
              attribute_types.keys.select do |attribute|
                attribute_types[attribute].searchable? && association_search?(attribute)
              end.each do |attribute|
                tables << if translation_search?(attribute)
                  {attribute => :translations}
                else
                  attribute
                end
              end
              tables + translation_join
            end

            def translation_join
              if attribute_types.values.any? {|field| field.translation?}
                [:translations]
              else
                []
              end
            end

            def translation_search?(attr)
              attribute_types[attr].translation?
            end

            def query_table_name(attr)
              table_name = if association_search?(attr)
                provided_class_name = attribute_types[attr].options[:class_name]
                if provided_class_name
                  provided_class_name.constantize.table_name
                else
                  attr.to_s.pluralize
                end
              else
                @scoped_resource.table_name
              end
              if translation_search?(attr)
                table_name = "#{table_name.singularize}_translations"
              end
              ActiveRecord::Base.connection.quote_table_name(table_name)
            end
          end
        end
      end
    end
  end
end
