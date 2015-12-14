def federation_configure
  DiasporaFederation.configure do |config|
    # the pod url
    config.server_uri = current_settings.my_url unless current_settings.nil?

    config.define_callbacks do
      on :fetch_person_for_webfinger do |id|
        DiasporaFederation::Discovery::WebFinger.new({
          acct_uri:    current_user.diaspora_id,
          alias_url:   "#{current_settings.my_url}/people/#{current_user.guid}",
          hcard_url:   "#{current_settings.my_url}/hcard/users/#{current_user.guid}",
          seed_url:    "#{current_settings.my_url}/",
          profile_url: "#{current_settings.my_url}/",
          atom_url:    "#{current_settings.my_url}/public/user.atom",
          salmon_url:  "#{current_settings.my_url}/receive/users/#{current_user.guid}",
          guid:        current_user.guid,
          public_key:  current_user.public_key.to_s
        })
      end

      on :fetch_person_for_hcard do |guid|
        DiasporaFederation::Discovery::HCard.new({
          guid:             current_user.guid,
          diaspora_handle:  current_user.diaspora_id,
          full_name:        current_user.name,
          url:              "#{current_settings.my_url}/",
          photo_large_url:  "#{current_settings.my_url}/profile.png",
          photo_medium_url: "#{current_settings.my_url}/profile.png",
          photo_small_url:  "#{current_settings.my_url}/profile.png",
          public_key:       current_user.public_key.to_s,
          searchable:       true,
          first_name:       current_user.name,
          last_name:        "",
          nickname:         current_user.name,
        })
      end

      on :save_person_after_webfinger do |person|
        Person.create(person.to_h).save
      end

      on :fetch_private_key_by_diaspora_id do |diaspora_id|
        current_user.private_key if diaspora_id == current_user.diaspora_id
      end

      on :fetch_private_key_by_user_guid do |guid|
        current_user.private_key if guid == current_user.guid
      end

      on :fetch_author_private_key_by_entity_guid do |entity_type, guid|
        if Object.const_get(entity_type).first(guid: guid).diaspora_id == current_user.diaspora_id
          current_user.private_key
        end
      end

      on :fetch_public_key_by_diaspora_id do |diaspora_id|
        Person.first(diaspora_id: diaspora_id).public_key
      end

      on :fetch_author_public_key_by_entity_guid do |entity_type, guid|
        klass = Object.const_get(entity_type)
        Person.first(diaspora_id: klass.first(guid).diaspora_id).public_key
      end

      on :entity_author_is_local? do |entity_type, guid|
        klass = Object.const_get(entity_type)
        user_guid = Users.find(diaspora_id: klass.first(guid).diaspora_id).guid
        !Users.find(guid: user_guid).nil?
      end
    
      on :fetch_entity_author_id_by_guid do |entity_type, guid|
        klass = Object.const_get(entity_type)
        klass.first(guid).diaspora_id
      end

      on :entity_persist do |entity, recipient_guid, sender_id|
        puts "entity_persist"
        puts "Entity received type:#{entity.class} from:#{sender_id} to:#{recipient_guid.nil? ? "public" : recipient_guid}"
      end
    end
  end
end
