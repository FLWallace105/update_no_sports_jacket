#update_two_items_sports_jacket.rb
require 'dotenv'
Dotenv.load
require 'httparty'
require 'resque'
require 'sinatra'
require 'active_record'
require "sinatra/activerecord"
#require_relative 'models/model'
#require_relative 'resque_helper'
Dir[File.join(__dir__, 'lib', '*.rb')].each { |file| require file }
Dir[File.join(__dir__, 'models', '*.rb')].each { |file| require file }



module FixSubInfo
  class SubUpdater
    include ReChargeLimits

    def initialize
      Dotenv.load
      recharge_regular = ENV['RECHARGE_ACCESS_TOKEN']
      @sleep_recharge = ENV['RECHARGE_SLEEP_TIME']
      @my_header = {
        "X-Recharge-Access-Token" => recharge_regular
      }
      @my_change_charge_header = {
        "X-Recharge-Access-Token" => recharge_regular,
        "Accept" => "application/json",
        "Content-Type" =>"application/json"
      }
      
    end

    def load_bad_sports_jacket_csv
        puts "Starting"
        SubscriptionsUpdated.delete_all
        # Now reset index
        ActiveRecord::Base.connection.reset_pk_sequence!('subscriptions_updated')
        num_not_found = 0
        CSV.foreach('no_sports_jacket_size.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
            #puts row.inspect
            subscription_id = row['subscription_id']
            temp_sub = Subscription.find_by_subscription_id(subscription_id)
            if temp_sub.nil?
                num_not_found += 1
            else
                puts temp_sub.inspect
                SubscriptionsUpdated.create(subscription_id: temp_sub.subscription_id, customer_id: temp_sub.customer_id, updated_at: temp_sub.updated_at, next_charge_scheduled_at: temp_sub.next_charge_scheduled_at, product_title: temp_sub.product_title, status: temp_sub.status, sku: temp_sub.sku, shopify_product_id: temp_sub.shopify_product_id, shopify_variant_id: temp_sub.shopify_variant_id, raw_line_items: temp_sub.raw_line_item_properties) 
            end
            

        end
        puts "We did not find #{num_not_found} subscriptions"

    end

    def fix_line_items(line_items)
        my_sports_jacket = line_items.select{|x| x['name'] == "sports-jacket"}
        if my_sports_jacket == []
            my_tops = line_items.select{|x| x['name'] == "tops"}
            if my_tops != []
                my_tops_size = my_tops.first['value']
                puts "my_tops_size = #{my_tops_size}"
                line_items << {"name"=>"sports-jacket", "value"=>my_tops_size}
            else
                puts "No tops"
                exit
            end
        else
            puts "found sports-jacket, not fixing"
        end
        return line_items

    end


    def update_bad_subs_sports_jacket
        puts "Starting"
        mysubs = SubscriptionsUpdated.where("updated = ?", false)
        mysubs.each do |mysub|
            puts "Subscription_id = #{mysub.subscription_id}"
            temp_line_items = mysub.raw_line_items
            puts "---- Before Fixing ------"
            puts temp_line_items.inspect
            puts "----- After Fixing --------"
            temp_line_items = fix_line_items(temp_line_items)
            puts temp_line_items.inspect
            puts "**************************"
            body = { "properties" => temp_line_items }.to_json
            

            my_update_sub = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{mysub.subscription_id}", :headers => @my_change_charge_header, :body => body, :timeout => 80)
            puts my_update_sub.inspect
            recharge_header = my_update_sub.response["x-recharge-limit"]
            determine_limits(recharge_header, 0.65)

            if my_update_sub.code == 200
                mysub.updated = true
                time_updated = DateTime.now
                time_updated_str = time_updated.strftime("%Y-%m-%d %H:%M:%S")
                mysub.processed_at = time_updated_str
                mysub.save
                puts "Updated subscription id #{mysub.subscription_id}"
                

            else
                puts "WE could not process / update this subscription."
            end

        end

        #product_collection_name = subscription['properties'].detect { |property| property['name'] == 'product_collection' }&.dig('value').to_s.downcase

    end


    def setup_matching_prepaid_orders_from_subs
        puts "Starting matching"

        UpdatePrepaidOrder.delete_all
            
        ActiveRecord::Base.connection.reset_pk_sequence!('update_prepaid')


        mysubs = SubscriptionsUpdated.all

        mysubs.each do |mysub|
            subscription_id = mysub.subscription_id
            puts "subscription_id = #{subscription_id}"
            my_sql = "select orders.order_id, orders.line_items from orders, order_line_items_fixed where orders.order_id = order_line_items_fixed.order_id and order_line_items_fixed.subscription_id = '#{subscription_id}' and orders.scheduled_at > '2020-08-06' and orders.scheduled_at < '2020-09-01' and orders.is_prepaid = '1' and orders.status = 'QUEUED' "

            ActiveRecord::Base.connection.execute(my_sql).each do |row|
                puts row.inspect

            end

        end

    end

  end
end