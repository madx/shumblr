#!/usr/bin/env shoes

$:.unshift(path = File.join(File.dirname(__FILE__), 'lib')) unless
  $:.include?(path)

require 'tumblr'

Shoes.app :title => "Shumblr.", :width => 700, :height => 600 do
  style Shoes::Para,  :stroke => white
  style Shoes::Title, :stroke => white, :font => '24px'

  background '#334668'
  background 'img/background.png', :height => 501, :width => 1.0

  @actions = {
    :text  => { 
      :fields => {
        :body   => [:required, :text], 
        :title  => [:optional, :line]
      },
      :method => :regular
    },
    :quote => { 
      :fields => {
        :text   => [:required, :text], 
        :source => [:optional, :text]
      },
      :method => :quote
    },
    :photo => { 
      :fields => {
        :source  => [:required, :line], 
        :caption => [:optional, :text]
      },
      :method => :photo,
    },
    :video => { 
      :fields => {
        :embed   => [:required, :line], 
        :caption => [:optional, :text]
      },
      :method => :video
    },
    :link  => { 
      :fields => {
        :url         => [:required, :line], 
        :name        => [:optional, :line], 
        :description => [:optional, :text]
      },
      :method => :link
    },
    :chat  => {
      :fields => {
        :conversation => [:required, :text],
        :title        => [:optional, :line]
      },
      :method => :conversation
    }
  }

  def home(&blk)
    @contents.clear do
      para strong("Welcome to Shumblr!\n"),
        "Shumblr is a client for Tumblr.\nYou can post to your Tumblr from ",
        "here without having to open your browser.\n\n",
        em("File uploads are not implemented yet!")
      yield if block_given?
    end
  end

  @credentials = flow :margin => 5 do
    @logged = false
    background rgb(255, 255, 128, 0.9), :curve => 5
    para "Credentials please:", :font => "bold", :stroke => black, :margin => 8
    $mail = edit_line "email",    :margin => 5
    $pass = edit_line "password", :margin => 5, :secret => true
    button "Ok", :margin => 4 do 
      @credentials.hide
      @logged = true
    end
  end

  banner "Shumblr.", :font => 'georgia,serif bold', :stroke => '#eee',
      :margin => [10, 5, 10, 5]

  
  stack :margin => [5, 0, 5, 5] do
    background rgb(51, 70, 104, 0.5), :curve => 12
    flow :margin => [110, 10, 145, 10] do
      background white, :curve => 5
      @actions.each do |action, opts|
        image "img/#{action}.png", :click => proc { create(action) }
      end
    end

    @contents = stack(:margin => 10)

    home
  end

  def create(action)
    unless @logged
      alert "Please login first!"
    else

      @contents.clear do
        @fields = {}
        @actions[action][:fields].each do |field, params|
          if params[0] == :required
            field_text = "#{field.to_s.capitalize}"
          else
            field_text = ["#{field.to_s.capitalize}", em(" (optional)")]
          end
          title field_text
          @fields[field] = case params[1]
            when :line: edit_line :width => 1.0, :margin => [10, 5, 10, 10]
            when :text: edit_box  :width => 1.0, :margin => [10, 5, 10, 10]
          end
        end
        @controls = flow do
          button "Post" do
            valid = true
            @actions[action][:fields].select {|k,v| 
              v[0] == :required 
            }.collect {|f| f[0] }.each do |field|
              if @fields[field].text.empty?
                alert "Field #{field.to_s.capitalize} can't be empty"
                valid = false
              end
            end

            @actions[action][:fields].select {|k,v|
              v[0] == :optional
            }.collect {|f| f[0] }.each do |field|
              text = @fields[field].text
              @fields[field].text = text.empty? ? nil : text
            end

            if valid
              write_to_api(@actions[action][:method], @fields)
            end
          end
          button("Cancel") { home }
        end
      end
    end
  end

  def write_to_api(method, params)
    begin
      Tumblr::API.write($mail.text, $pass.text, "Shumblr") do
        case method
          when :regular
            regular(params[:body].text, params[:title].text)
          when :link
            link(params[:url].text, params[:name].text, params[:description].text)
          when :conversation
            conversation(params[:conversation].text, params[:title].text)
          when :quote
            quote(params[:text].text, params[:source].text)
          when :video
            video(params[:embed].text, params[:caption].text)
          when :photo
            photo(params[:source].text, params[:caption].text)
        end
      end
      home { para "Content published!", :stroke => green, :font => 'bold' }
    rescue Tumblr::API::AuthError
      alert "Authentication error"
      @credentials.show
      @logged = false
    rescue => e
      alert "#{e.class}, not published"
    end
  end
end
