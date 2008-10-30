#!/usr/bin/ruby

require "net/http"
require "uri"
require "rexml/document"
require "tzinfo"
require "time"
require "tumblr/version"

module Tumblr
  class Data
    attr_accessor :tumblelog, :posts
    
    def initialize(doc = nil)
      if doc
        @tumblelog = Tumblelog.new(REXML::XPath.first(doc, "//tumblelog"))
        @posts = Posts.new(REXML::XPath.first(doc, "//posts"), @tumblelog.timezone)
      end
    end
    
    def self.load(path)
      new(REXML::Document.new(File.read(path)))
    end

    def save(path)
      File.open(path, "w") do |file|
        doc = REXML::Document.new
        root = doc.add_element "ruby-tumblr", {"version" => "0.1"}
        root.elements << @tumblelog.to_xml if @tumblelog
        root.elements << @posts.to_xml if @posts
        doc.write(file)
      end
    end

    def <<(other)
      @tumblelog = other.tumblelog unless @tumblelog
      @posts ? @posts.push(*other.posts) : @posts = other.posts
    end

    class Tumblelog
      attr_accessor :name, :timezone, :cname, :title, :description

      def initialize(elt)
        @name = elt.attributes["name"]
        @timezone = TZInfo::Timezone.get(elt.attributes["timezone"])
        @cname = elt.attributes["cname"]
        @title = elt.attributes["title"]
        @description = elt.text
      end

      def to_xml
        elt = REXML::Element.new("tumblelog")
        elt.attributes["name"] = @name
        elt.attributes["timezone"] = @timezone.name
        elt.attributes["cname"] = @cname
        elt.attributes["title"] = @title
        elt.text = @description
        return elt
      end
    end

    class Posts < Array
      attr_accessor :total, :start, :type

      def initialize(elt, tz)
        @total = elt.attributes["total"].to_i
        @start = elt.attributes["start"].to_i if elt.attributes.has_key? "start"
        @type = elt.attributes["type"]
        
        elt.elements.each("post") do |e|
          push((case e.attributes["type"]
           when "regular"; Regular
           when "quote"; Quote
           when "photo"; Photo
           when "link"; Link
           when "video"; Video
           when "conversation"; Conversation
          end).new(e, tz))
        end
      end

      def to_xml
        elt = REXML::Element.new("posts")
        elt.attributes["total"] = @total
        elt.attributes["type"] = @type
        each do |post|
          elt.elements << post.to_xml
        end
        return elt
      end
    end

    class Post
      attr_reader :postid, :url, :date, :bookmarklet
      
      def initialize(elt, tz)
        @postid = elt.attributes["id"]
        @url = elt.attributes["url"]
        @date = Time.parse(elt.attributes["date"] + tz.strftime("%Z"))
        @bookmarklet = (elt.attributes["bookmarklet"] == "true")
        @timezone = tz
      end

      def to_xml
        elt = REXML::Element.new("post")
        elt.attributes["id"] = @postid
        elt.attributes["date"] = @date.strftime("%a, %d %b %Y %X")
        elt.attributes["bookmarklet"] = "true" if @bookmarklet
        elt.attributes["url"] = @url
        return elt
      end
    end

    class Regular < Post
      attr_accessor :title, :body
      
      def initialize(elt, tz)
        super
        if elt.elements["regular-title"]
          @title = elt.elements["regular-title"].text
        end
        if elt.elements["regular-body"]
          @body = elt.elements["regular-body"].text
        end
      end
      
      def to_xml
        elt = super
        elt.attributes["type"] = "regular"
        if @title
          (elt.add_element("regular-title")).text = @title
        end
        if @body
          (elt.add_element("regular-body")).text = @body
        end
        return elt
      end
    end

    class Quote < Post
      attr_accessor :text, :source
      
      def initialize(elt, tz)
        super
        @text = elt.elements["quote-text"].text
        if elt.elements["quote-source"]
          @source = elt.elements["quote-source"].text
        end
      end
      
      def to_xml
        elt = super
        elt.attributes["type"] = "quote"
        et = elt.add_element("quote-text")
        et.text = @text
        if @source
          (elt.add_element("quote-source")).text = @source
        end
        return elt
      end
    end

    class Photo < Post
      attr_accessor :caption, :urls
      
      def initialize(elt, tz)
        super
        if elt.elements["photo-caption"]
          @caption = elt.elements["photo-caption"].text
        end
        @urls = Hash.new
        elt.elements.each("photo-url") do |url|
          @urls[url.attributes["max-width"].to_i] = url.text
        end
      end

      def to_xml
        elt = super
        elt.attributes["type"] = "photo"
        if @caption
          (elt.add_element "photo-caption").text = @caption
        end
        @urls.each do |width, url|
          e = elt.add_element "photo-url", {"max-width" => width}
          e.text = url
        end
        return elt
      end
    end

    class Link < Post
      attr_accessor :name, :url, :description
      
      def initialize(elt, tz)
        super
        @text = elt.elements["link-text"].text if elt.elements["link-text"]
        @url = elt.elements["link-url"].text
        @description = elt.elements["link-description"].text if elt.elements["link-description"]
      end
      
      def to_xml
        elt = super
        elt.attributes["type"] = "link"
        name = elt.add_element "link-text"
        name.text = @text
        url = elt.add_element "link-url"
        url.text = @url
        description = elt.add_element "link-description"
        description.text = @description
        return elt
      end
    end

    class Conversation < Post
      attr_accessor :title, :lines
      
      def initialize(elt, tz)
        super
        if elt.elements["conversation-title"]
          @title = elt.elements["conversation-title"]
        end
        @text = elt.elements["conversation-text"].text
        @lines = []
        elt.elements.each("conversation-line") do |line|
          name = line.attributes["name"]
          label = line.attributes["label"]
          @lines << [name, label, line.text]
        end
      end
      
      def to_xml
        elt = super
        elt.attributes["type"] = "conversation"
        if @title
          (elt.add_element "conversation-title").text = @title
        end
        text = elt.add_element "conversation-text"
        text.text = @text
        @lines.each do |line|
          e = elt.add_element "conversation-line", {"name" => line[0], "label" => line[1]}
          e.text = line[2]
        end
        return elt
      end
    end

    class Video < Post
      def initialize(elt, tz)
        super
        @caption = elt.elements["video-caption"].text
        @source = elt.elements["video-source"].text
        @player = elt.elements["video-player"].text
      end

      def to_xml
        elt = super
        elt.attributes["type"] = "video"
        caption = elt.add_element "video-caption"
        caption.text = @caption
        player = elt.add_element "video-player"
        player.text = @player
        source = elt.add_element "video-source"
        source.text = @source
        return elt
      end
    end
  end

  module API
    class ResponseError < StandardError
      attr_reader :response
      def initialize(response)
        @response = response
      end
    end
    
    class AuthError < StandardError; end
    
    class BadRequestError < StandardError
      attr_reader :message
      def initialize(message)
        @message = message
      end
    end

    class Reader
      attr_accessor :http, :start, :num, :type
      
      def initialize(http, num=20, type=nil)
        @http = http
        @num = num
        @type = type
        @total = request(0, 0).posts.total
      end
      
      def last_page
        ((@total - 1) / @num) + 1
      end
      
      def page(pos)
        request(pos*@num, @num)
      end

      private
      
      def request(start, num)
        req = Net::HTTP::Post.new "/api/read"
        data = {"start" => start, "num" => num}
        data["type"] = @type if @type
        req.set_form_data data
        res = http.request(req)
        if res.kind_of?(Net::HTTPSuccess)
          return Tumblr::Data.new(REXML::Document.new(res.body))
        else
          raise ResponseError.new(res)
        end
      end
    end

    def self.read(hostname, num=20, type=nil, &b)
      Net::HTTP.start(hostname) do |http|
        reader = Reader.new(http, num, type)
        reader.instance_eval &b
      end
    end

    class Writer
      attr_accessor :http, :email, :password, :generator
      
      def initialize(http, email, password, generator)
        @http = http
        @email = email
        @password = password
        @generator = generator
      end
      
      def regular(body, title=nil)
        post("type" => "regular", "title" => title, "body" => body)
      end
      
      def quote(text, source=nil)
        post("type" => "quote", "quote" => text, "source" => source)
      end
      
      def photo(source, caption=nil)
        post("type" => "photo", "caption" => caption, "source" => source)
      end

      def link(url, name=nil, description=nil)
        post("type" => "link", "name" => name, "url" => url, "description" => description)
      end
      
      def conversation(conversation, title=nil)
        post("type" => "conversation", "title" => title, "conversation" => conversation)
      end

      def video(embed, caption=nil)
        post("type" => "video", "embed" => embed, "caption" => caption)
      end
      
      def post(data)
        req = Net::HTTP::Post.new "/api/write"
        req.set_form_data({
          "email" => @email,
          "password" => @password,
          "generator" => @generator
        }.merge(data))
        res = @http.request req
        case res.code
        when '201'
          return res.body.chomp
        when '403'
          raise AuthError.new
        when '400'
          raise BadRequestError.new(res.body)
        else
          raise ResponseError.new(res)
        end
      end
    end
    
    def self.write(email, password, generator="ruby-tumblr", &b)
      Net::HTTP.start("www.tumblr.com") do |http|
        writer = Writer.new(http, email, password, generator)
        writer.instance_eval &b
      end
    end

  end
end
