class BoolNanny::Railtie < Rails::Railtie
  rake_tasks do
    load 'tasks/nil_to_false.rake'
  end
end