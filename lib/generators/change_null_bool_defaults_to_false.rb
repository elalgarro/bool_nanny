require_relative(Rails.root.to_s + '/config/environment.rb')

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
  @bool_cols ||= {'true'=>{}, 'false'=>{}}
  if @bool_cols['true'].empty? && @bool_cols['false'].empty? 
    Dir[Rails.root.join('app/models/*.rb').to_s].each do |filename|
      klass = File.basename(filename, '.rb').camelize.constantize
      next unless klass.ancestors.include?(ActiveRecord::Base)
      next if klass.abstract_class?
      klass.columns.each do |c| 
        if c.type.to_s == 'boolean' && c.null.to_s == 'true'
          t_or_f = c.default ? 'true' : 'false'
          update_nulls_to_false klass, c.name.to_sym, t_or_f
          if @bool_cols[t_or_f][klass.table_name.to_sym].present?
            @bool_cols[t_or_f][klass.table_name.to_sym] << c.name.to_sym
          else
            @bool_cols[t_or_f][klass.table_name.to_sym] = [c.name.to_sym]
          end
        end
      end
    end
  end
  @bool_cols
end
def update_nulls_to_false model, attr, value
  puts "updating #{model}, #{attr}..."
  value = value == "true"
  working = true
  unless model.unscoped.where(attr => nil).update_all(attr.to_sym => value)
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
    #{get_bool_cols['false']}.each do |table, attrs|
      attrs.each do |attr|
        change_column table, attr, :boolean, null: false, default: false
      end
    end
    #{get_bool_cols['true']}.each do |table, attrs|
      attrs.each do |attr|
        change_column table, attr, :boolean, null: false, default: true
      end
    end
    " }  

puts "successfully populated migration"
puts "migrating..."
system "rake db:migrate"
puts "successfully ran migration"