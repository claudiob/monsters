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
          summary = get_doc 'http://developer.echonest.com/api/v4/song/search', 
          {:api_key => ENV['ECHONEST_KEY'], :format => 'xml', :results => 1,
           :artist => artist, :title => title, :bucket => 'audio_summary'},
           '/response/songs/song/audio_summary', false
          tempo = summary.first.find_first('tempo').content
          mode = summary.first.find_first('mode').content
           
          unless tempo.nil? || tempo.empty?
            print "Trying tempo: #{tempo}\n"

            tracks_id = get_doc 'http://api.7digital.com/1.2/track/search',
            {:oauth_consumer_key => "musichackday", :country => 'gb', 
             :q => title}, '/response/searchResults/searchResult/track', false
            tracks_id.each do |track|
              print "Trying audio: #{track["id"]}\n"
              artist_name = track.find_first("artist/name").content
              if artist_name.downcase.eql? artist.downcase
                @audio = "http://api.7digital.com/1.2/track/preview?trackId=#{track["id"].to_i}&country=gb&oauth_consumer_key=musichackday"
                @tempo = tempo.to_i
                @mode = mode.to_i
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
    @mode ||= 1
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
    tempo = params[:tempo].nil? || params[:tempo].empty? ? 120 : params[:tempo].to_i
    tag = params[:tag].nil? || params[:tag].empty? ? "pop" : params[:tag]
    mode = 0 #params[:mode].nil? || params[:mode].empty? ? 1 : params[:mode]
    docs.gsub! /svg10.dtd\">/, "svg10.dtd\" [ <!ENTITY animDuration \"#{60000/tempo/500.0}\"> ]>"
    # Set the color given the tag
    print "tag: #{params[:tag]}"
    docs.gsub! /#93CFC9/, GENRES[tag.downcase]
    # Remove width/height
    docs.gsub! /width="(.*?)px" height="(.*?)px"/, ""
    docs.gsub! /viewBox="(.*?)" enable-background="(.*?)"/, "viewBox=\"0 0 160 240.687\""
    # Add background
    if mode.zero? # minor
      docs.gsub! /xml:space="preserve">/, "xml:space=\"preserve\"><rect fill=\"#2E243A\" width=\"160\" height=\"240.001\"/>
<rect y=\"200.105\" fill=\"#4D4D4D\" width=\"160\" height=\"40.581\"/>
<path fill=\"#CCCCCC\" d=\"M34.896,36.538c-4.157-6.287-3.904-14.209,0.016-20.119c-2.331,0.432-4.616,1.328-6.718,2.718
	c-8.391,5.548-10.695,16.848-5.147,25.237c5.548,8.392,16.847,10.694,25.237,5.147c2.102-1.39,3.822-3.141,5.132-5.117
	C46.442,45.696,39.054,42.828,34.896,36.538z\"/>
<polygon fill=\"#808080\" points=\"91.186,18.116 91.953,19.67 93.666,19.919 92.426,21.128 92.719,22.836 91.186,22.029 
	89.652,22.836 89.945,21.128 88.705,19.919 90.419,19.67 \"/>
<polygon fill=\"#808080\" points=\"49.767,25.033 50.534,26.586 52.248,26.836 51.008,28.045 51.3,29.752 49.767,28.946 48.234,29.752 
	48.526,28.045 47.286,26.836 49,26.586 \"/>
<polygon fill=\"#808080\" points=\"70.249,42.477 71.125,44.252 73.084,44.537 71.667,45.919 72.001,47.87 70.249,46.949 68.496,47.87 
	68.831,45.919 67.413,44.537 69.372,44.252 \"/>"
    else
      docs.gsub! /xml:space="preserve">/, "xml:space=\"preserve\"><rect fill=\"#EFF8FA\" width=\"160\" height=\"240.001\"/>
      <g>
      	<circle fill=\"#F9E925\" cx=\"119.225\" cy=\"47.119\" r=\"23.076\"/>
      </g>
      <g>
      	<path fill=\"#F9E925\" d=\"M87.934,46.27c0.002-15.549,12.604-28.148,28.15-28.15l0,0c15.543,0.002,28.146,12.601,28.148,28.15l0,0c-0.002,15.545-12.605,28.146-28.148,28.148l0,0C100.538,74.417,87.936,61.815,87.934,46.27L87.934,46.27z M88.935,46.27c0.026,14.992,12.155,27.121,27.149,27.148l0,0c14.992-0.027,27.121-12.156,27.146-27.148l0,0c-0.024-14.996-12.153-27.123-27.146-27.15l0,0C101.09,19.147,88.961,31.274,88.935,46.27L88.935,46.27z\"/>
      </g>
      <g>
      	<path fill=\"#F9E925\" d=\"M87.935,40.343c0-16.998,13.78-30.783,30.783-30.783l0,0c17,0,30.78,13.785,30.78,30.783l0,0h0.002c-0.002,17.002-13.784,30.783-30.782,30.783l0,0C101.715,71.126,87.935,57.346,87.935,40.343L87.935,40.343z M88.936,40.343c0.029,16.449,13.331,29.752,29.782,29.782l0,0c16.446-0.029,29.752-13.333,29.781-29.782l0,0c-0.029-16.446-13.335-29.752-29.781-29.781l0,0C102.267,10.591,88.965,23.897,88.936,40.343L88.936,40.343z\"/>
      </g>
      <rect y=\"200.105\" fill=\"#4D4D4D\" width=\"160\" height=\"40.581\"/>"
    end
    
    respond_with(docs) do |format|
      format.svg {render :xml => docs}
    end
    
  end  

end
