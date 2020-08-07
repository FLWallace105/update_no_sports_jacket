require 'dotenv'
Dotenv.load

require 'active_record'
#require 'sinatra'
require 'sinatra/activerecord/rake'
require_relative 'update_two_items_sports_jacket'


namespace :two_items do
desc 'load bad subs from CSV'
task :load_bad_subs_csv do |t|
    FixSubInfo::SubUpdater.new.load_bad_sports_jacket_csv
end

desc 'update bad subs with sports-jacket size picked from tops'
task :fix_bad_subs_sports_jacket do |t|
    FixSubInfo::SubUpdater.new.update_bad_subs_sports_jacket
end

desc 'setup matching prepaid orders'
task :setup_matching_prepaid_orders do |t|
    FixSubInfo::SubUpdater.new.setup_matching_prepaid_orders_from_subs
end


end