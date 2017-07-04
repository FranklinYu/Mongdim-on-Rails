# If false, `FooController` only includes module FooHelper from `app/helpers/foo_helper.rb`,
# instead of all the helpers in `app/helpers/` directory.
# `BarHelper` can be manually included in `FooController` with the help of [`helper` method][1].
# Previous versions had false.
#
# [1]: http://api.rubyonrails.org/v5.1.1/classes/AbstractController/Helpers/ClassMethods.html#method-i-helper
Rails.application.config.action_controller.include_all_helpers = false
