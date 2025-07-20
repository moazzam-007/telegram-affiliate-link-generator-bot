require 'sinatra'
require_relative 'lib/bot'

# Bot ko ek alag background thread mein shuru karein
Thread.new do
  puts "Starting Telegram Bot in background..."
  Bot.new
end

# Main thread web server chalayega
get '/' do
  "Bot is running in the background!"
end
