class MonstersController < ApplicationController

  respond_to :html, :only => :index
  respond_to :svg, :only => :monster

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
    docs.gsub! /svg10.dtd\">/, "svg10.dtd\" [ <!ENTITY animDuration \"#{60000/params[:tempo].to_i/500.0}\"> ]>"
    render :xml => docs
    
  end  
  
  def index
    if params[:username]
      # Last.fm > get last track played
      require 'httpclient'
      require 'xml'
      @user_agent = HTTPClient.new(:agent_name => 'musichackday')
      response_body = @user_agent.__send__('get_content', 
      'http://ws.audioscrobbler.com/2.0/', 
      {:method => 'user.gettopartists', :api_key => ENV['LASTFM_KEY'], 
        :user => params[:username]})
      xml = XML::Document.string(response_body)
      artists = xml.find('/lfm/topartists/artist/name')
      artists.each do |artist|
        response_body = @user_agent.__send__('get_content', 
        'http://ws.audioscrobbler.com/2.0/', 
        {:method => 'artist.gettoptags', :api_key => ENV['LASTFM_KEY'], 
          :artist => artist.content})
        xml = XML::Document.string(response_body)
        name = xml.find('/lfm/toptags/tag/name').first
        if name && ["pop", "rock"].include?(name.content)
          @tag = name.content 
          @artist = artist.content
          response_body = @user_agent.__send__('get_content', 
          'http://ws.audioscrobbler.com/2.0/', 
          {:method => 'artist.gettoptracks', :api_key => ENV['LASTFM_KEY'], 
            :artist => @artist})
          xml = XML::Document.string(response_body)
          name = xml.find('/lfm/toptracks/track/name').first
          if name
            @title = name.content
            break
          end
          if @title
            break
          end
        end
      end

      # Echonest > get tempo
      response_body = @user_agent.__send__('get_content', 
      'http://developer.echonest.com/api/v4/song/search', 
      {:api_key => ENV['ECHONEST_KEY'], :format => 'xml', :results => 1,
        :artist => URI.escape(@artist.downcase), :title => URI.escape(@title.downcase), 
        :bucket => 'audio_summary'})
      xml = XML::Document.string(response_body)
      @tempo = xml.find('/response/songs/song/audio_summary/tempo').first.content.to_s.to_i
  
      # 7Digital > get audio
      response_body = @user_agent.__send__('get_content', 
      'http://api.7digital.com/1.2/track/search', 
      {:oauth_consumer_key => "musichackday", :country => 'gb', :q => @title})
      xml = XML::Document.string(response_body)
      require 'ruby-debug'
      debugger
      xml.find('/response/searchResults/searchResult/track').each do |track|
        if track.find_first("artist/name").content.downcase.eql? @artist.downcase
          @track_id = track["id"].to_i
          break
        end
      end
      @audio = "http://api.7digital.com/1.2/track/preview?trackId=#{@track_id}&country=gb&oauth_consumer_key=musichackday" if @track_id
  
      # Musixmatch > get lyrics
      response_body = @user_agent.__send__('get_content', 
      'http://api.musixmatch.com/ws/1.0/track.search', 
      {:apikey => "76e154ecb5d823bcde107c1b20789ea4", :q_artist => @artist,
       :q_track => @title, :format => 'xml', :page_size => '1', :f_has_lyrics => '1'})
      xml = XML::Document.string(response_body)
      lyrics_id = xml.find('/message/body/track_list/track/lyrics_id').first.content.to_i
      response_body = @user_agent.__send__('get_content', 
      'http://api.musixmatch.com/ws/1.0/lyrics.get', 
      {:apikey => "76e154ecb5d823bcde107c1b20789ea4", :lyrics_id => lyrics_id,
       :format => 'xml'})
      xml = XML::Document.string(response_body)
      @lyrics = xml.find('/message/body/lyrics_list/lyrics/lyrics_body').first.content

    end
  end

end
