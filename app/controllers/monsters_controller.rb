class MonstersController < ApplicationController

  respond_to :html, :svg
  
  def index
  end

  def show
    require 'lastfm'
    api_keys = YAML.load_file Rails.root.join('config', 'api_keys.yml')
    lastfm = Lastfm.new api_keys['lastfm']['key'], api_keys['lastfm']['secret']
    tracks = lastfm.user.get_loved_tracks(params[:username])
    # just some test
    @fill = tracks["lovedtracks"]["track"].first["artist"]["mbid"][0..5]
    @stroke = tracks["lovedtracks"]["track"].second["artist"]["mbid"][0..5]

    respond_with(@fill) do |format|
      format.html
      format.svg {render :xml => "<?xml version=\"1.0\" encoding=\"iso-8859-1\" standalone=\"no\"?>
      <?xml-stylesheet href=\"monsters.css\" type=\"text/css\"?>
      <!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.0//EN\" \"http://www.w3.org/TR/SVG/DTD/svg10.dtd\">
      <svg viewBox=\"-2361 0 4625 2336\" width=\"280\" height=\"123\"
           xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" xml:space=\"preserve\">
       <g id=\"staatsgr\">
      	<ellipse fill=\"##{@fill}\" stroke=\"##{@stroke}\" class=\"fil0 str0\" cx=\"200\" cy=\"1335\" rx=\"150\" ry=\"120\"/>
      	<ellipse fill=\"##{@fill}\" stroke=\"##{@stroke}\" class=\"fil0 str0\" cx=\"-200\" cy=\"1335\" rx=\"150\" ry=\"120\"/>
      	<ellipse fill=\"##{@fill}\" stroke=\"##{@stroke}\" class=\"fil0 str0\" cx=\"500\" cy=\"735\" rx=\"150\" ry=\"120\"/>
      	<ellipse fill=\"##{@fill}\" stroke=\"##{@stroke}\" class=\"fil0 str0\" cx=\"-500\" cy=\"735\" rx=\"150\" ry=\"120\"/>
      	<ellipse fill=\"##{@fill}\" stroke=\"##{@stroke}\" class=\"fil0 str0\" cx=\"0\" cy=\"735\" rx=\"550\" ry=\"520\"/>
       </g>

      </svg>"}
    end
        
  end

end
