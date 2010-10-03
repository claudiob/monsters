class MonstersController < ApplicationController

  respond_to :html, :only => :index
  respond_to :svg, :only => :monster
  require 'httpclient'
  require 'xml'

  # We couldn't make them all!
  # GENRES = {"acoustic" => "#6B3E15", "ambient" => "#73E5FF", "blues" => 
  #  "#262261", "classical" => "#901C24", "country" => "#A87C4F", 
  #  "electronic" => "#06FFFF", "emo" => "#91D2CB", "folk" => "#EA6936", 
  #  "hardcore" => "#000", "hip hop" => "#C19A23", "indie" => "#000F02", 
  #  "jazz" => "#1B75BB", "latin" => "#9E1F63", "metal" => "#000", 
  #  "pop" => "#FF00A4", "pop punk" => "#D91C5C", "punk" => "#000", 
  #  "reggae" => "#EC1C24, #FFF100, #009345", "rnb" => "#461175",
  #  "rock" => "#000", "soul" => "#660200", "world" => "#FFAA00", 
  #  "60s" => "#D6DE23", "70s" => "#E76E34", "80s" => "#EB008B", 
  #  "90s" => "#CCCCCC"}
  GENRES = {"acoustic" => "#6B3E15", "emo" => "#91D2CB", "hip hop" => 
    "#C19A23", "pop" => "#FF00A4", "punk" => "#000", "rock" => "#000"}

  def get_doc(host, params, xml_tag, content = true)
    @user_agent = HTTPClient.new(:agent_name => 'musichackday')
    response_body = @user_agent.__send__('get_content', host, params)
    xml = XML::Document.string(response_body).find(xml_tag)
    return content ? xml.collect(&:content) : xml
  end

  def index
    sample_users = {:emo => 'RealitySound', :hip_hop => 'nigz0r', :pop => 
      'luizf3ernando', :acoustic => 'timecircuits', :rock => 'xnetuno',
      :punk => 'Ferlyrusuh'}
    @random_user = sample_users.values[rand(sample_users.length)]

    
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
        # NOTE: Might as well use BMAT Ella, if it were public!!
        # titles = get_doc "http://ella.bmat.ws/collections/bmat/artists/#{URI.escape artist}/tracks", 
        # {}, '/resultset/results/track/metadata/track'

        titles_from_artist = 0
        titles.each do |title|
          titles_from_artist = titles_from_artist + 1
          break if titles_from_artist >=5 # try another artist
          print "Trying title: #{title}\n"
          
          # Echonest > get tempo
          summary = get_doc 'http://developer.echonest.com/api/v4/song/search', 
          {:api_key => ENV['ECHONEST_KEY'], :format => 'xml', :results => 1,
           :artist => artist, :title => title, :bucket => 'audio_summary'},
           '/response/songs/song/audio_summary', false
          analysis = summary.first
          unless analysis.nil?
            tempo = analysis.find_first('tempo').content
            mode = analysis.find_first('mode').content
            loudness = analysis.find_first('loudness').content
             
            unless tempo.nil? || tempo.empty?
            print "Trying tempo: #{tempo}\n"

            tracks_id = get_doc 'http://api.7digital.com/1.2/track/search',
            {:oauth_consumer_key => "musichackday", :country => 'gb', 
             :q => title}, '/response/searchResults/searchResult/track', false
            tracks_id.each do |track|
              print "Trying audio: #{track["id"]}\n"
              artist_name = track.find_first("artist/name").content
              if artist_name.downcase.eql? artist.downcase

                # Musixmatch > get lyrics
                lyrics_id = get_doc 'http://api.musixmatch.com/ws/1.0/track.search',
                {:apikey => ENV['MUSIXMATCH_KEY'], :q_artist => artist,
                 :q_track => title, :format => 'xml', :page_size => '1',
                 :f_has_lyrics => '1'}, '/message/body/track_list/track/lyrics_id'
                unless lyrics_id.nil? || lyrics_id.empty?
                  print "Trying lyrics: #{lyrics_id.first}\n"
                  lyrics = get_doc 'http://api.musixmatch.com/ws/1.0/lyrics.get',
                  {:apikey => ENV['MUSIXMATCH_KEY'], :lyrics_id => lyrics_id.first,
                   :format => 'xml'}, '/message/body/lyrics_list/lyrics/lyrics_body'
                  unless lyrics.nil? || lyrics.empty?
                    @lyrics = lyrics.first
                    @audio = "http://api.7digital.com/1.2/track/preview?trackId=#{track["id"].to_i}&country=gb&oauth_consumer_key=musichackday"
                    @tempo = tempo.to_f
                    @mode = mode.to_i.zero? ? "minor" : "major"
                    @loudness = loudness.to_f
                    @title = title
                    @artist = artist
                    @tag = tags.first
                    break
                  end
                end
              end
            end
            break if @audio
          end
          end
        end
        break if @artist
      end
    end      
    @lyrics ||= "music lover"
    @title ||= "Paparazzi" # Just in case
    @tempo ||= 120  # Just in case
    @mode ||= "major"
    @artist ||= "Lady Gaga" # Just in case no top artist has a top tag
    @tag ||= "pop" # Just in case no top artist has a top tag

    split = @lyrics.gsub(/[^A-Za-z \n]/, "").split().uniq()
    split.delete_if{|x| @title.downcase.include? x.downcase}
    split.sort!{|y, x| x.length <=> y.length}
    first_two = split.first(2)
    @name = split[0][0..split[0].length/3] + ['a','e','i','o','u'][rand(5)] + split[1][split[1].length/2..split[1].length]
    suffixes = ['us', 'una', 'eel', 'erie', 'ina', 'ape', 'ine', 'el', 'ode', 'orn', 'er', 'eon', 'uto', 'owl', 'ichu', 'ola', 'itar', 'yle', 'oom', 'oose', 'otic', 'eus']
    @name << suffixes[rand(suffixes.length)]
  


  end

  def monster

    tempo = params[:tempo].nil? || params[:tempo].empty? ? 120 : params[:tempo].to_i
    tag = params[:tag].nil? || params[:tag].empty? ? "pop" : params[:tag].downcase
    mode = params[:mode].nil? || params[:mode].empty? ? "major" : params[:mode]
    loudness = params[:loudness].nil? || params[:loudness].empty? ? 0 : params[:loudness]

    tag = "pop" unless GENRES.keys.include? tag

    parser = XML::Parser.file Rails.root.join('public', 'svg', "#{tag}_1.svg")
    doc = parser.parse
    # Remove <pattern>
    doc.find_first('*').remove!

    parser2 = XML::Parser.file Rails.root.join('public', 'svg', "#{tag}_2.svg")
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
    docs.gsub! /svg10.dtd\">/, "svg10.dtd\" [ <!ENTITY animDuration \"#{60000/tempo/500.0}\"> ]>"
    # Set the color given the tag
    docs.gsub! /#93CFC9/, GENRES[tag.downcase]
    # NOTE: Here I could do docs.gsub! /fill="#93CFC9"/, "fill=\"#{GENRES[tag.downcase]}\" opacity=\"0.2\""
    # to change the opacity based on loudness, but since the background is solid, you would not appreciate it
    # Remove width/height
    docs.gsub! /width="(.*?)px" height="(.*?)px"/, ""
    #docs.gsub! /viewBox="(.*?)" enable-background="(.*?)"/, "viewBox=\"0 0 389 600\""
    # Add background
    if mode.eql? "minor" # minor
      docs.gsub! /xml:space="preserve">/, "><rect fill=\"#4D4D4D\" width=\"389\" height=\"600\"/>
      <rect y=\"498.553\" fill=\"#383838\" width=\"389\" height=\"100\"/>
      <path fill=\"#E0CE99\" d=\"M81.917,90.814c-10.377-15.693-9.744-35.467,0.04-50.22c-5.818,1.08-11.522,3.315-16.769,6.786
      	C44.244,61.229,38.492,89.434,52.34,110.373c13.849,20.949,42.052,26.694,62.994,12.849c5.247-3.471,9.54-7.842,12.81-12.771
      	C110.735,113.674,92.295,106.515,81.917,90.814z\"/>
      <polygon fill=\"#AAAAAA\" points=\"222.42,44.833 224.334,48.71 228.611,49.333 225.516,52.35 226.247,56.613 222.42,54.6 
      	218.591,56.613 219.324,52.35 216.229,49.333 220.506,48.71 \"/>
      <polygon fill=\"#AAAAAA\" points=\"119.036,62.098 120.951,65.973 125.229,66.597 122.132,69.616 122.861,73.875 119.036,71.865 
      	115.208,73.875 115.938,69.616 112.842,66.597 117.121,65.973 \"/>
      <polygon fill=\"#AAAAAA\" points=\"170.161,105.64 172.348,110.069 177.236,110.78 173.7,114.23 174.534,119.101 170.161,116.801 
      	165.785,119.101 166.621,114.23 163.082,110.78 167.972,110.069 \"/>"
    else
      docs.gsub! /xml:space="preserve">/, "><rect fill=\"#E1F4F1\" width=\"389\" height=\"598.288\"/>
      <g>
      	<circle fill=\"#E5C467\" cx=\"291.579\" cy=\"120.772\" r=\"57.112\"/>
      </g>
      <g>
      	<path fill=\"#E5C467\" d=\"M214.137,118.673c0.004-38.483,31.193-69.666,69.67-69.671l0,0c38.47,0.005,69.659,31.188,69.663,69.671
      		l0,0c-0.004,38.472-31.193,69.659-69.663,69.663l0,0C245.331,188.333,214.141,157.146,214.137,118.673L214.137,118.673z
      		 M216.615,118.673c0.062,37.104,30.08,67.122,67.189,67.188l0,0c37.104-0.066,67.121-30.084,67.187-67.188l0,0
      		c-0.062-37.115-30.078-67.128-67.187-67.196l0,0C246.695,51.545,216.677,81.558,216.615,118.673L216.615,118.673z\"/>
      </g>
      <g>
      	<path fill=\"#E5C467\" d=\"M214.141,104.001c0-42.066,34.104-76.184,76.187-76.184l0,0c42.072,0,76.178,34.116,76.178,76.184l0,0
      		h0.006c-0.006,42.081-34.114,76.187-76.184,76.187l0,0C248.243,180.188,214.141,146.085,214.141,104.001L214.141,104.001z
      		 M216.615,104.001c0.072,40.711,32.996,73.638,73.71,73.71l0,0c40.702-0.071,73.636-32.999,73.706-73.71l0,0
      		c-0.07-40.701-33.004-73.634-73.706-73.704l0,0C249.611,30.368,216.688,63.3,216.615,104.001L216.615,104.001z\"/>
      </g>
      <rect y=\"500\" fill=\"#4D4D4D\" width=\"389\" height=\"100\"/>
      <rect fill=\"none\" width=\"389\" height=\"600\"/>"
    end
    
    respond_with(docs) do |format|
      format.svg {render :xml => docs}
    end
    
  end  

end
