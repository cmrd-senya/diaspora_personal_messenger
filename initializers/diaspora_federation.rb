def federation_configure
  DiasporaFederation.configure do |config|
    # the pod url
    config.server_uri = current_settings.my_url unless current_settings.nil?

    config.define_callbacks do
      on :fetch_person_for_webfinger do |id|
        DiasporaFederation::Discovery::WebFinger.new(
          acct_uri:    current_user.diaspora_id,
          alias_url:   "#{current_settings.my_url}/people/#{current_user.guid}",
          hcard_url:   "#{current_settings.my_url}/hcard/users/#{current_user.guid}",
          seed_url:    "#{current_settings.my_url}/",
          profile_url: "#{current_settings.my_url}/",
          atom_url:    "#{current_settings.my_url}/public/user.atom",
          salmon_url:  "#{current_settings.my_url}/receive/users/#{current_user.guid}",
          guid:        current_user.guid,
          public_key:  current_user.public_key.to_s
        )
      end

      on :fetch_person_for_hcard do |guid|
        DiasporaFederation::Discovery::HCard.new(
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
        )
      end

      on :save_person_after_webfinger do |person|
        data = person.to_h
        data[:diaspora_id] = data.delete(:author)
        Person.create(data).save
      end

      on :fetch_related_entity do |type, guid|
        DiasporaFederation::Entities::RelatedEntity.new(Post.first(guid).attributes)
      end

      on :fetch_person_url_to do |author, path|
        Person.find_or_fetch_by_diaspora_id(author).url + path
      end

      on :queue_public_receive do |xml, _legacy|
        puts "queue_public_receive"
        DiasporaFederation::Federation::Receiver.receive_public(xml)
      end

      on :queue_private_receive do |guid, xml, _legacy|
        puts "queue_private_receive(guid=#{guid}, xml=#{xml})"
        rsa_key = User.first(guid: guid).private_key
        DiasporaFederation::Federation::Receiver.receive_private(xml, rsa_key, guid)
      end

      on :fetch_private_key do |diaspora_id|
        current_user.private_key if diaspora_id == current_user.diaspora_id
      end

      on :fetch_public_key do |diaspora_id|
        Person.first(diaspora_id: diaspora_id).public_key
      end

      on :receive_entity do |entity, sender, recipient|
        puts "Entity received type:#{entity.class} from:#{sender} to:#{recipient.nil? ? "public" : recipient}"
        if entity.class == DiasporaFederation::Entities::StatusMessage
          entity_hash = entity.to_h
          Post.create(
            %i(guid author public).map {|key| [key, entity_hash[key]]}.to_h
          ).save!
        elsif entity.class == DiasporaFederation::Entities::Comment
          puts "Comment = #{entity.to_h}"
        end
      end

      on :fetch_public_entity do |entity_type, guid|
        puts "fetch_public_entity"
      end

      on :update_pod do |url, status|
        puts "update_pod"
      end
    end
  end
end
