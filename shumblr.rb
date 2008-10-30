#!/usr/bin/env shoes

$:.unshift(path = File.join(File.dirname(__FILE__), 'lib')) unless
  $:.include?(path)

require 'tumblr'

Shoes.app :title => "Shumblr.", :width => 700, :height => 600 do
  style Shoes::Para,  :stroke => white
  style Shoes::Title, :stroke => white, :font => '24px'
  background '#334668'
  background 'img/background.png', :height => 501, :width => 1.0
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
    flow :margin => [80, 10, 90, 10] do
      background white, :curve => 5
      image 'img/text.png',  :click => proc { check { new_text } }
      image 'img/photo.png', :click => proc { check { } }
      image 'img/quote.png', :click => proc { check { } }
      image 'img/link.png',  :click => proc { check { } }
      image 'img/chat.png',  :click => proc { check { } }
      image 'img/audio.png', :click => proc { check { } }
      image 'img/video.png', :click => proc { check { } }
    end

    @contents = stack :margin => 10 do
      para strong("Welcome to Shumblr!\n"),
        "Shumblr is a client for Tumblr.\nYou can post to your Tumblr from ",
        "here without having to open your browser.\n\n",
        "Shumblr never reminds your login information, so you'll have ",
        "to remember it."

    end
  end

  def new_text
    @contents.clear do

      title "Title"
      @title = edit_line :width => 1.0, :margin => [10, 5, 10, 10]

      title "Text"
      @text  = edit_box :width => 1.0, :margin => [10, 5, 10, 10]

      @controls = flow do
        button "Post" do
          text = @text.text
          title = @title.text
          if title.empty? || title.nil?
            alert "No title provided"
          elsif text.empty? || text.nil?
            alert "No text provided"
          else
            write_to_api { regular(text, title) }
            @controls.clear do
              para "Text published, ", 
                link("Return to home", :click => proc { cancel })
            end
          end
        end
        button("Cancel") { cancel }
      end
    end
  end

  def cancel
    @contents.clear {}
  end

  def check(&blk)
    if @logged then yield else alert "Please login first" end
  end

  def write_to_api(&blk)
    Tumblr::API.write($mail.text, $pass.text, &blk)
  end
end
