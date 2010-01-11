#!/usr/bin/env ruby
require 'rubygems'
require 'cgi'
require 'net/http'
require 'open-uri'
require 'iconv'
require 'ruby-debug'
require 'rchardet'

def fixed_text text,size
  space_size = size - text.size
  return text if space_size < 0
  space_size.times { text += " " }
  text
end

def rate_bar(value)
  length,bar = 10, ""
  (length*value/200).times { bar += "-" }
  "[#{fixed_text(bar,length)}]"
end

class String
  def to_utf8
    encoding = CharDet.detect(self)["encoding"] || "GB2312"
    Iconv.conv('utf-8',encoding,self)
  end
end

class SongInfo
  attr_accessor :title, :id, :rate, :presenter, :url
  def initialize hash
    @title     = hash[:title]
    @id        = hash[:id]
    @rate      = hash[:rate]
    @presenter = hash[:presenter]
    @url       = nil
  end

  def get_url
    response = Net::HTTP.get(URI.parse("http://www.songtaste.com/song/#{id}/"))
    href = response.match(/playmedia1.{1,500}Listen/)[0].split("\', \'")
    @url = href[5].split("\')\;Lis")[0] + href[1]
  end

  def download
    music_dir = "/home/binku/media/music/#{Time.now.year}.#{Time.now.month}"
    Dir.mkdir music_dir unless File.directory?(music_dir)
    `wget #{@url} -P #{music_dir}`
    `cd #{music_dir} && mv preview #{title}.mp3`
  end

  def try_listening
    get_url if @url.nil?
    `mplayer #{@url}`
  end
end

class Util
end

class SongTaste
  attr_reader :songs,:song

  def get_list page = ""
    @songs = []
    http = Net::HTTP.new("www.songtaste.com" + page.to_s)
    response = http.request_get('/music/')
    response.body.scan(/MSL.*?\)\;/).each do |e|
      begin
        title = e.split("\"")[1].split("--")[0]
        id = e.split("\"")[3]
        rate = e.split("\"")[11]
        presenter = e.split("\"")[5].strip.delete(".")
        @songs << SongInfo.new(:title => title.to_utf8, :id => id, :rate => rate.to_i, :presenter => presenter.to_utf8)
      rescue Iconv::IllegalSequence
      end
    end
  end

  def show_list page = ""
    get_list(page) if @songs.nil?
    @songs.sort! { |x,y| y.rate <=> x.rate }
    num = 1
    @songs.each do |song|
      puts "#{num < 10 ? " #{num}" : num}.#{rate_bar(song.rate)}#{song.title}"#(#{presenter.to_utf8})"
      num += 1
    end
    puts "(Num)Listening (R).Refrash List (N).Next Page (P).Pre Page (Q).Quit"
  end

  def select_song id
    @song = @songs[id] 
  end

  def try_listening
    return puts("unselect songs yet") if @song.nil?
    puts "(Q)Quit (P)Pause"
    @song.try_listening
    puts "(L)List (D)Download (R)Reply"
  end

  def download
    return puts("unselect songs yet") if @song.nil?
    @song.download 
  end
end

songtaste = SongTaste.new
songtaste.show_list

while(command = gets)
  command.chop!
  exit if command.downcase == "q"
  if command.to_i > 0
    songtaste.select_song(command.to_i)
    songtaste.try_listening
    case gets.chop!.downcase
    when "l"
      songtaste.show_list
    when "d"
      songtaste.download
    when "r"
      songtaste.try_listening    
    end
  end
end
