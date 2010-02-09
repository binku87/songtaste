#!/usr/bin/env ruby
require 'rubygems'
require 'cgi'
require 'net/http'
require 'open-uri'
require 'iconv'
require 'ruby-debug'
require 'colored'

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
    Iconv.conv('utf-8',"GB2312",self)
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
  attr_reader :songs,:song,:current_page
  TRYLISTENING = 0
  DOWNLOAD = 1
  SHOWLIST = 2

  def initialize
    @songs = []
    @current_page = 0
  end

  def get_list
    http = Net::HTTP.new("www.songtaste.com" + (@current_page == 0 ? "" : @current_page.to_s))
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

  def show_list page = nil 
    @current_page = page unless page.nil?
    get_list if @songs.empty?
    @songs.sort! { |x,y| y.rate <=> x.rate }
    num = 1
    @songs.each do |song|
      puts "#{num < 10 ? " #{num}" : num}.".red_on_white + "#{rate_bar(song.rate)}".green + "#{song.title}"#(#{presenter.to_utf8})"
      num += 1
    end
  end

  def show_next_list
    @current_page += 1
    show_list
  end

  def show_prev_list
    @current_page = @current_page == 0 ? 0 : @current_page - 1
    show_list
  end

  def select_song id
    @song = @songs[id] 
  end

  def try_listening
    return puts("unselect songs yet") if @song.nil?
    puts "Title:".red.bold + "#{@song.title}".white.bold
    puts "(Q)Quit (P)Pause".blue_on_white
    @song.try_listening
  end

  def download
    return puts("unselect songs yet") if @song.nil?
    @song.download 
  end

  def note_after_cmd cmd
    case cmd
    when TRYLISTENING
      puts "Current Selected Song:" + @song.title
      puts "(L)List (D)Download (R)Reply (N).Next Page (P).Prev Page (Q).Quit".blue_on_white
    when SHOWLIST
      puts "(Num)Listening (U).Refrash List (N).Next Page (P).Prev Page (Q).Quit".blue_on_white
    when DOWNLOAD
      puts "(L)List (R)Reply (U).Refrash List (N).Next Page (P).Prev Page (Q).Quit".blue_on_white
    end
  end
end

songtaste = SongTaste.new
songtaste.show_list
songtaste.note_after_cmd(SongTaste::SHOWLIST)

while(command = gets)
  case command.chop!.downcase
  when "q" 
    exit
  when /[0-9]{1,3}/
    songtaste.select_song(command.to_i)
    songtaste.try_listening
    songtaste.note_after_cmd(SongTaste::TRYLISTENING)
  when "l"
    songtaste.show_list
    songtaste.note_after_cmd(SongTaste::SHOWLIST)
  when "d"
    songtaste.download
    songtaste.note_after_cmd(SongTaste::DOWNLOAD)
  when "r"
    songtaste.try_listening
    songtaste.note_after_cmd(SongTaste::TRYLISTENING)
  when "n"
    songtaste.show_next_list 
    songtaste.note_after_cmd(SongTaste::SHOWLIST)
  when "p"
    songtaste.show_prev_list 
    songtaste.note_after_cmd(SongTaste::SHOWLIST)
  end
end
