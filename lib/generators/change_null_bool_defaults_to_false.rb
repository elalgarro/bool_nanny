require_relative(Rails.root + '/config/environment.rb')

puts 'creating migration...'
system "rails g migration AddDefaultValueToBooleans"
puts 'successfully created migration'
file = ""
# 
Dir[Rails.root.join('db/migrate/*.rb').to_s].each do |filename|
  if filename.include? "add_default_value_to_booleans"
     file =  filename 
  end
end

def replace(filepath, regexp, *args, &block)
  content = File.read(filepath).gsub(regexp, *args, &block)
  File.open(filepath, 'wb') { |file| file.write(content) }
end

def get_bool_cols
  @bool_cols ||= {}
  if @bool_cols.empty?
    Dir[Rails.root.join('app/models/*.rb').to_s].each do |filename|
      klass = File.basename(filename, '.rb').camelize.constantize
      next unless klass.ancestors.include?(ActiveRecord::Base)
      next if klass.abstract_class?
      klass.columns.each do |c| 
        if c.type.to_s == 'boolean' && c.null.to_s == 'true'
          update_nulls_to_false klass, c.name.to_sym
          if @bool_cols[klass.table_name.to_sym].present?
           @bool_cols[klass.table_name.to_sym] << c.name.to_sym
         else
           @bool_cols[klass.table_name.to_sym] = [c.name.to_sym]
         end
        end
      end
    end
  end
  @bool_cols
end
def update_nulls_to_false model, attr
  puts "updating #{model}, #{attr}..."
  working = true
  unless model.unscoped.where(attr => nil).update_all(attr.to_sym => false)
      working = false
  end
  if working 
    puts " successfully updated #{model}, #{attr}"
  else
    puts "<<<< ERROR updating #{model}, #{attr}"
  end
end
get_bool_cols
puts 'populating  migration field'
replace( file, /..def.change/mi) { |match| "
  def change
    #{get_bool_cols}.each do |table, attrs|
      attrs.each do |attr|
        default = table.to_s == 'projects_users' && attr.to_s == 'onsite'
        change_column table, attr, :boolean, null: false, default: default
      end
    end" }  

puts "successfully populated migration"
puts "migrating..."
system "rake db:migrate"
puts "successfully ran migration"