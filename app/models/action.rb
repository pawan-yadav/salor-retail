class Action < ActiveRecord::Base
  include SalorScope
  include SalorBase
  include SalorModel
  belongs_to :role
  belongs_to :vendor
  belongs_to :owner, :polymorphic => true
  def value=(v)
    v = v.gsub(',','.') if v.class == String
    write_attribute(:value,v)
  end
  def self.when_list
    [:add_to_order,:always,:on_save,:on_import,:on_export]
  end
  def code=(text)
    if code.match(/User|Employee|Vendor|Order|OrderItem|DrawerTransaction/) then
      self.errors[:base] << I18n.t("system.errors.cannot_use_in_code")
    end
    write_attribute(:code,text)
  end
  def self.behavior_list
    [:add,:subtract,:multiply, :divide, :assign]
  end
  def self.afield_list
    [:base_price, :quantity,:tax_profile_id]
  end
  def sku=(s)
    if not s.blank? then
      item = Item.find_by_sku(s)
      if item then
        self.owner_id = item.id
        self.owner_type = 'Item'
      else
        self.errors[:base] << I18n.t("system.errors.no_such_item")
      end
    end
  end
  def sku
    owner = self.owner
    if owner then
      return owner.sku
    else
      return ''
    end
  end
  def self.run(item,act)
    if item.class == OrderItem then
      base_item = item.item
    else
      base_item = item
    end
      base_item.actions.each do |action|
        # puts "Considering action: #{action.behavior} #{action.whento}"
        if act == action.whento.to_sym or action.whento.to_sym == :always  then
          # puts "Running action: #{action.behavior} #{action.whento}"
          if action.value > 0 then
            begin
              eval("item.#{action.afield} += action.value") if action.behavior.to_sym == :add 
              eval("item.#{action.afield} -= action.value") if action.behavior.to_sym == :subtract
              eval("item.#{action.afield} *= action.value") if action.behavior.to_sym == :multiply 
              eval("item.#{action.afield} /= action.value") if action.behavior.to_sym == :divide
              eval("item.#{action.afield} = action.value") if action.behavior.to_sym == :assign
              if item.class == OrderItem then
               item.update_attribute :action_applied, true
              end
            rescue
              # puts "Error: #{$!}"
              GlobalErrors.append("system.errors.action_error",action,{:error => $!})
            end
          else
            # puts "ActionValue is #{action.value}"
          end
          if not action.code.blank? then
            begin
              # puts "evaluating code"
              eval(action.code)
            rescue
              # puts "There was an error #{$!}"
              GlobalErrors.append("system.errors.action_code_error",action,{:error => $!})
            end
          end
        end
      end
      # puts "At the end of actions, #{item.price}"
      
    return item
  end
  def self.simulate(item,action)
     if action.value > 0 then
        begin
          item[action.afield.to_sym] += action.value if action.behavior.to_sym == :add 
          item[action.afield.to_sym] -= action.value if action.behavior.to_sym == :subtract
          item[action.afield.to_sym] *= action.value if action.behavior.to_sym == :multiply
          item[action.afield.to_sym] /= action.value if action.behavior.to_sym == :divide
          item[action.afield.to_sym] = action.value if action.behavior.to_sym == :assign
        rescue
          GlobalErrors.append("system.errors.action_error",action,{:error => $!})
        end
      end
      return item
  end
end
