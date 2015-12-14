require "logging"
require "ripl"
require "diaspora_federation"
require "diaspora_federation-sinatra_app"
require "./db-schema"
require "./initializers/diaspora_federation"

def create_message(conversation_guid, message)
  message = DiasporaFederation::Entities::Message.new(
    parent_guid:       conversation_guid,
    guid:              UUID.generate(:compact),
    text:              message,
    diaspora_id:       current_user.diaspora_id,
    conversation_guid: conversation_guid
  )
  Message.create(message.to_h.delete_if {|key,value| key.to_s.include? "signature"}).save!
  message
end

def create_conversations(recipient_id, message)
  conversation_guid = UUID.generate :compact

  Conversation.create(
    guid:        conversation_guid,
    diaspora_id: current_user.diaspora_id
  ).save!
  DiasporaFederation::Entities::Conversation.new(
    guid:            conversation_guid,
    subject:         "private conversation",
    messages:        [create_message(conversation_guid, message)],
    diaspora_id:     current_user.diaspora_id,
    participant_ids: "#{current_user.diaspora_id};#{recipient_id}"
  )
end

def send_entity(recipient_id, entity)
  recipient = Person.find_or_fetch_by_diaspora_id(recipient_id)
  raise "Failed to fetch person with id #{recipient_id}" if recipient.nil?
  DiasporaFederation::HydraWrapper.new(
    current_user,
    [recipient],
    entity,
    false
  ).tap do |hydra|
    hydra.enqueue_batch
    hydra.run
  end
end

def send_message(recipient_id, message)
  send_entity(recipient_id, create_conversations(recipient_id, message))
end

def send_request(recipient_id)
  send_entity(
    recipient_id,
    DiasporaFederation::Entities::Request.new(
      sender_id:    current_user.diaspora_id,
      recipient_id: recipient_id
    )
  )
end

def set_myhost(myhost)
  if current_settings.nil?
    Settings.create(myhost: myhost)  
  else
    current_settings.tap do |settings|
      settings.myhost = myhost
      settings.save!
    end
  end

  DiasporaFederation.configure do |config|
    config.server_uri = myhost
  end
end

def help
  "No usage help available yet."
end

DataMapper.setup( :default, "sqlite3://#{Dir.pwd}/settings.db" )
DataMapper.auto_upgrade!

class FederationEndpoints < DiasporaFederation::SinatraApp
  set :bind, "0.0.0.0"

  get "/" do
    ""
  end

  get "/people/:guid/stream" do
    "{}"
  end
end

if current_settings.nil? || current_settings.myhost.nil?
  puts "Please set your publicly accessible address with set_myhost \"address\""
else
  puts "Your public address is set to #{current_settings.myhost}"
end

if current_user.nil?
  puts "Please create a user with create_user \"name\""
else
  puts "Current user name is \"#{current_user.name}\""
end

federation_configure

web_server = Thread.new do
  FederationEndpoints.run!
end

while !FederationEndpoints.running? do
  sleep 1
end

puts "Diaspora Personal Messenger loaded. Type \"help\" for usage."
Ripl.start
Thread.kill(web_server)
