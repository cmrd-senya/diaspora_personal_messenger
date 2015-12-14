require "uuid"
require "dm-core"
require "dm-migrations"

class Settings
  include DataMapper::Resource

  property :id,   Serial

  property :myhost, String

  def my_url
    "http://#{myhost}"
  end
end

class User
  include DataMapper::Resource

  property :id,   Serial

  property :guid, String, :required => true

  property :name, String, :required => true

  # @!attribute [r] exported_key private key
  property :exported_key, Text, :required => true

  def diaspora_id
    "#{name}@#{current_settings.myhost}"
  end

  def public_key
    OpenSSL::PKey::RSA.new(exported_key).public_key
  end

  def private_key
    OpenSSL::PKey::RSA.new(exported_key)
  end
end

class Person
  include DataMapper::Resource

  property :id,   Serial

  # @!attribute [r] guid
  #   @see HCard#guid
  #   @return [String] guid
  property :guid, String, :required => true, :unique => true

  # @!attribute [r] url
  #   @see WebFinger#seed_url
  #   @return [String] link to the pod
  property :url, String

  # @!attribute [r] exported_key public key
  #   @see HCard#public_key
  #   @return [String] public key
  property :exported_key, Text, :required => true

  property :diaspora_id, String, :required => true

  property :profile, Text

  def public_key
    OpenSSL::PKey::RSA.new exported_key
  end

  def receive_url
    "#{url}/receive/users/#{guid}"
  end

  def self.find_or_fetch_by_diaspora_id(diaspora_id)
    person = Person.first(diaspora_id: diaspora_id)
    return person unless person.nil?
    DiasporaFederation::Discovery::Discovery.new(diaspora_id).fetch_and_save
    Person.first(diaspora_id: diaspora_id)
  end
end

class Message
  include DataMapper::Resource

  property :guid, String, :required => true, :unique => true, :key => true

  property :text, String

  property :diaspora_id, String

  property :conversation_guid, String

  property :parent_guid, String

  property :created_at, Time
end

class Conversation
  include DataMapper::Resource

  property :guid, String, :required => true, :unique => true, :key => true

  property :diaspora_id, String
end

def create_user(name)
  user = User.create(
    guid:        UUID.generate(:compact),
    name:        name,
    exported_key: OpenSSL::PKey::RSA.new(2048).to_s
  )
  user.save!
  Person.create(
    guid:         user.guid,
    exported_key: user.exported_key,
    diaspora_id:  user.diaspora_id
  ).save!
end

def current_user
  User.all.last
end

def current_settings
  Settings.all.first
end
