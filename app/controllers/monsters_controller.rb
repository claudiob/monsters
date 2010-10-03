class MonstersController < ApplicationController

  respond_to :html, :only => :index
  respond_to :svg, :only => :monster
  require 'httpclient'
  require 'xml'

  GENRES = 
  {"acoustic" => "#6B3E15", "ambient" => "#73E5FF", "blues" => "#262261", "classical" => "#901C24", "country" => "#A87C4F", "electronic" => "#06FFFF", "emo" => "#91D2CB", "folk" => "#EA6936", "hardcore" => "#000", "hip hop" => "#C19A23", "indie" => "#000F02", "jazz" => "#1B75BB", "latin" => "#9E1F63", "metal" => "#000", "pop" => "#FF00A4", "pop punk" => "#D91C5C", "punk" => "#000", "reggae" => "#EC1C24, #FFF100, #009345", "rnb" => "#461175", "rock" => "#000", "soul" => "#660200", "world" => "#FFAA00", "60s" => "#D6DE23", "70s" => "#E76E34", "80s" => "#EB008B", "90s" => "#CCCCCC"}

  def get_doc(host, params, xml_tag, content = true)
    @user_agent = HTTPClient.new(:agent_name => 'musichackday')
    response_body = @user_agent.__send__('get_content', host, params)
    xml = XML::Document.string(response_body).find(xml_tag)
    return content ? xml.collect(&:content) : xml
  end

  def index
    return unless params[:username]

    # Last.fm > get top artists for a user
    artists = get_doc 'http://ws.audioscrobbler.com/2.0/', 
    {:method => 'user.gettopartists', :api_key => ENV['LASTFM_KEY'], 
      :user => params[:username]}, '/lfm/topartists/artist/name'

    # Last.fm > get top tag for the top artist
    artists.each do |artist|
      print "Trying artist: #{artist}\n"
      tags = get_doc 'http://ws.audioscrobbler.com/2.0/', 
      {:method => 'artist.gettoptags', :api_key => ENV['LASTFM_KEY'], 
        :artist => artist}, '/lfm/toptags/tag/name'
      tags.delete_if{|tag| !GENRES.keys.include? tag.downcase}
      unless tags.nil? || tags.empty?
        print "Trying tag: #{tags.first}\n"

        # Last.fm > get top track for the top artist
        titles = get_doc 'http://ws.audioscrobbler.com/2.0/', 
        {:method => 'artist.gettoptracks', :api_key => ENV['LASTFM_KEY'], 
          :artist => artist}, '/lfm/toptracks/track/name'
        titles.each do |title|
          print "Trying title: #{title}\n"
          
          # Echonest > get tempo
          tempo = get_doc 'http://developer.echonest.com/api/v4/song/search', 
          {:api_key => ENV['ECHONEST_KEY'], :format => 'xml', :results => 1,
           :artist => artist, :title => title, :bucket => 'audio_summary'},
           '/response/songs/song/audio_summary/tempo'
          unless tempo.nil? || tempo.empty?
            print "Trying tempo: #{tempo.first}\n"

            tracks_id = get_doc 'http://api.7digital.com/1.2/track/search',
            {:oauth_consumer_key => "musichackday", :country => 'gb', 
             :q => title}, '/response/searchResults/searchResult/track', false
            tracks_id.each do |track|
              print "Trying audio: #{track["id"]}\n"
              artist_name = track.find_first("artist/name").content
              if artist_name.downcase.eql? artist.downcase
                @audio = "http://api.7digital.com/1.2/track/preview?trackId=#{track["id"].to_i}&country=gb&oauth_consumer_key=musichackday"
                @tempo = tempo.first.to_i
                @title = title
                @artist = artist
                @tag = tags.first
                break
              end
            end
            break if @audio
          end
        end
        break if @artist
      end
    end      
    @title ||= "Paparazzi" # Just in case
    @tempo ||= 120  # Just in case
    @artist ||= "Lady Gaga" # Just in case no top artist has a top tag
    @tag ||= "pop" # Just in case no top artist has a top tag

    # Musixmatch > get lyrics
    # response_body = @user_agent.__send__('get_content', 
    # 'http://api.musixmatch.com/ws/1.0/track.search', 
    # {:apikey => "76e154ecb5d823bcde107c1b20789ea4", :q_artist => @artist,
    #  :q_track => @title, :format => 'xml', :page_size => '1', :f_has_lyrics => '1'})
    # xml = XML::Document.string(response_body)
    # lyrics_id = xml.find('/message/body/track_list/track/lyrics_id').first.content.to_i
    # response_body = @user_agent.__send__('get_content', 
    # 'http://api.musixmatch.com/ws/1.0/lyrics.get', 
    # {:apikey => "76e154ecb5d823bcde107c1b20789ea4", :lyrics_id => lyrics_id,
    #  :format => 'xml'})
    # xml = XML::Document.string(response_body)
    # @lyrics = xml.find('/message/body/lyrics_list/lyrics/lyrics_body').first.content

  end



  def monster

    parser = XML::Parser.file Rails.root.join('public', 'svg', 'emo_1.svg')
    doc = parser.parse
    # Remove <pattern>
    doc.find_first('*').remove!

    parser2 = XML::Parser.file Rails.root.join('public', 'svg', 'emo_2.svg')
    doc2 = parser2.parse
    # Remove <pattern>
    doc2.find_first('*').remove!

    anim_values = []
    doc2.root.children.each do |path| 
      anim_values << path["d"]
    end

    i = 0
    doc.root.children.each do |path| 
      if anim_values[i]
        animate = XML::Node.new('animate') 
        animate.output_escaping= false
        animate["dur"] = "animDuration;"
        animate["repeatCount"] = "indefinite"
        animate["attributeName"] = "d"
        animate["values"] = "#{path["d"]};#{anim_values[i]};#{path["d"]}"
        path << animate
      end
      i = i+1
    end

    docs = doc.to_s
    docs.gsub! /animDuration;/, "&animDuration;"
    tempo = params[:tempo].empty? ? 120 : params[:tempo].to_i
    tag = params[:tag].empty? ? "pop" : params[:tag]
    docs.gsub! /svg10.dtd\">/, "svg10.dtd\" [ <!ENTITY animDuration \"#{60000/tempo/500.0}\"> ]>"
    # Set the color given the tag
    print "tag: #{params[:tag]}"
    docs.gsub! /#93CFC9/, GENRES[tag.downcase]
    
    respond_with(docs) do |format|
      format.svg {render :xml => docs}
    end
    
  end  

end
