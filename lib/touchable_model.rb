module TouchableModel
  def self.included(model)
    model.extend(TouchableModel::ClassMethods)
    model.send(:include, TouchableModel::InstanceMethods)

    underscore_name = model.name.underscore.singularize
    plural_name = underscore_name.pluralize

    # Include this module to have any related class set the updated_at field after it is saved
    # after they are saved. The class is expected to have an association that matches the
    # underscored name of the touchable model.
    model.class_eval <<-CODE
      module TouchOnSave
        def self.included(base)
          base.send(:after_save, :touch_#{underscore_name})
          base.class_eval do
            def touch_#{underscore_name}
              if self.respond_to?(:#{plural_name})
                item_ids = self.#{plural_name}(true).map(&:id)
                #{model.name}.touch_instances(item_ids)
              elsif self.respond_to?(:#{underscore_name})
                item = self.#{underscore_name}(true)
                item.touch_without_validation! if item.present?
              end
            end
          end
        end
      end
    CODE
  end

  module InstanceMethods
    def touch_without_validation!
      self.class.touch_instances([self.id])
    end
  end

  module ClassMethods
    def method_missing(symbol, *args)
      plural_name = self.name.underscore.pluralize
      if symbol == "touch_#{plural_name}".to_sym
        return self.touch_instances(*args)
      else
        super
      end
    end

    def touch_#{plural_name}(instance_ids = nil)
      self.touch_instances(instance_ids)
    end

    def touch_instances(instance_ids = nil)
      touch_time = Time.now.utc
      instance_ids ||= []
      self.update_all(['updated_at = ?', touch_time], ['id IN (?)', instance_ids]) if instance_ids.present?
    end
  end
end

