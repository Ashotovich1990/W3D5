require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    @content ||= DBConnection.execute2(<<-SQL)
  SELECT
    *
  FROM
    "#{self.table_name}"
  SQL
  @content[0].map {|el| el.to_sym}
  end

  def self.finalize!
    columns.each do |column|

      define_method(column) do 
        self.attributes[column]
      end

      define_method("#{column}=") do |val|
        self.attributes[column] = val
     end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.name.tableize
  end

  def self.all
  parse_all(DBConnection.execute(<<-SQL)
  SELECT
    *
  FROM
    "#{self.table_name}"
  SQL
  )
  end

  def self.parse_all(results)
   results.map {|params| self.new(params)}
  end

  def self.find(id)
    parse_all(DBConnection.execute(<<-SQL, id)
  SELECT
    *
  FROM
    "#{self.table_name}"
  WHERE 
   id = ?
  SQL
    )[0]
  end

  def initialize(params = {})
   params_sym = params.map {|k,v| [k.to_sym, v]}.to_h

   params_sym.keys.each do |attr_name|
    raise "unknown attribute '#{attr_name}'" unless self.class.columns.include?(attr_name)
   end
   
   params_sym.each do |attr_name, val|
    self.send("#{attr_name}=",val)
   end

  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    attributes.values
  end

  def insert
    col_names = self.class.columns[1..-1].join(", ")
    question_marks = (["?"] * (self.class.columns.size - 1)).join(", ")

  DBConnection.execute2(<<-SQL, attribute_values)
   INSERT INTO 
   "#{self.class.table_name}" (#{col_names})
   VALUES
    (#{question_marks})
  SQL

  self.id = DBConnection.last_insert_row_id
  end

  def update
    col_names = self.class.columns.map {|attr| "#{attr} = ?"}.join(",")
    
    DBConnection.execute(<<-SQL, *attribute_values, id)
   UPDATE
   #{self.class.table_name}
   SET
    #{col_names}
   WHERE 
   #{self.class.table_name}.id = ?
  SQL
  end

  def save
    if self.class.find(id).nil? 
       insert
    else 
       update
    end
  end
end
