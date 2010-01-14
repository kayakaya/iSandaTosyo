#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'sinatra'
require 'rack'
require 'uri'
require 'erb'
require 'open-uri'
require 'nokogiri'
require 'nkf'

configure do
  Encoding.default_external = 'UTF-8'
end

configure :development do

  set :public, (File.dirname(__FILE__) + "/public")
  set :views, (File.dirname(__FILE__) + "/public/views")
  set :base_url, ''

  class Sinatra::Reloader < Rack::Reloader
    def safe_load(file, mtime, stderr = $stderr)
      if file == __FILE__ then
        ::Sinatra::Application.reset!
        ::Sinatra::Application.use_in_file_templates! file
        stderr.puts "#{self.class}: reseting routes"
      end
      super
    end
  end
  use Sinatra::Reloader
end

# ここを参考に
# http://blog.livedoor.jp/faulist/archives/1219486.html
module Rack
  module Utils
    def escape_html(s)
      s.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/) {
        '%'+$1.unpack('H2'*bytesize($1)).join('%').upcase
      }.tr(' ', '+')
    end
  end
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

def search(search_type, word, page)

  word_sjis = NKF::nkf("-Ws", word)

  key1 = search_type == 'title' ? URI.encode(word_sjis) : ''
  key2 = search_type == 'author' ? URI.encode(word_sjis) : ''

  url = "http://libweb.area-sanda-hyogo.jp/toshow/asp/Book_Kensaku_w.asp?hidKensakuF=1&Page=#{page}&taiz=1&sel1=1&key1=#{key1}&sel2=2&key2=#{key2}&sel3=3&key3=&sel4=4&key4=&andor=0&SortKubun=1&isbn=&book1=1&year-from=&year-to="

  str = open(url).read
  doc = Nokogiri::HTML(str, nil, 'cp932')
  @books = Array.new
  doc.xpath('/html/body/table/tr/td/table/tr').each do |elem|
    title_elem = elem.css('td a')
    if !title_elem.empty? then
      bookinfo = Hash.new

      # タイトルの最初に改行コードが含まれているのでカットしておく
      bookinfo[:title] = title_elem.text.gsub(/\r\n/,'')
      bookinfo[:id] = title_elem.attr('href').to_s.sub(/.*TosCode=/,'')
      bookinfo[:author] = elem.css('td[3]').text
      bookinfo[:publisher] = elem.css('td[4]').text
      bookinfo[:ndc] = elem.css('td[5]').text
      bookinfo[:stock_honkan] = elem.css('td[6]').text
      bookinfo[:stock_ai] = elem.css('td[7]').text
      bookinfo[:stock_woody] = elem.css('td[8]').text

      @books << bookinfo
    end
  end
  if search_type == 'title' then
    @title = '書名検索'
  else
    @title = '著者名検索'
  end

  # 次の画面へのリンクを取得'
  @next = doc.xpath('//tr/td/p[2]/a[2]/@href')
  @leftnav = "<a href='#{options.base_url}/'><img alt='home' src='#{options.base_url}/images/home.png' /></a>"

  @base_url = options.base_url

end

def rows_info_of_books(detail)

  index = {
    :title => 3,
    :author => 6,
    :publisher => 8,
    :year => 9,
    :ndc => 10,
    :pages => 11,
    :size => 12,
    :isbn => 13,
    :description => 14
  }

  index_has_second_author = {
    :title => 3,
    :author => 6,
    :publisher => 9,
    :year => 11,
    :ndc => 12,
    :pages => 13,
    :size => 14,
    :isbn => 15,
    :description => 16
  }
  index_is_series = {
    :title => 3,
    :author => 8,
    :publisher => 10,
    :year => 11,
    :ndc => 12,
    :pages => 13,
    :size => 14,
    :isbn => 15,
    :description => 16
  }

  # 著者名2、叢書名がある場合は行が増えるので、取得する行を変更しておく
  is_second_author = detail.xpath('./tr/td[1][contains(.,"著者名２")]')
  is_series = detail.xpath('./tr/td[1][contains(.,"叢書名")]')
  if !is_second_author.empty? then
    index = index_has_second_author
  elsif !is_series.empty? then
    index = index_is_series
  end
  return index

end


get '/?' do
  @base_url =  options.base_url
  @title = 'iSandaTosyo'
  erb :index
end

get '/title?' do
  redirect "#{options.base_url}/title/#{URI.escape(params[:word])}" if params[:word]
  redirect '#{options.base_url}/'
end
get '/author?' do
  redirect "#{options.base_url}/author/#{URI.escape(params[:word])}" if params[:word]
  redirect '#{options.base_url}/'
end

get '/title/:word' do

  @word = params['word']

  redirect '/' if !@word or @word.empty?
  @page = params[:page] || '1'
  @search_type = 'title'

  search(@search_type, @word, @page)
  erb :search

end

get '/author/:word' do

  @word = params[:word]

  redirect '/' if !@word or @word.empty?
  @page = params[:page] || '1'
  @search_type = 'author'

  search(@search_type, @word, @page)
  erb :search

end

get '/title/word/page' do

  @word = params[:word]
  @page = params[:page] || '1'
  search(@search_type, @word, @page)
  erb :search

end

get '/author/:word/page' do

  @word = params[:word]
  @page = params[:page] || '1'
  search(@search_type, @word, @page)
  erb :search

end

get '/book/:id' do

  @id = params[:id]
  redirect '/' if !@id or @id.empty?
  @url = "http://libweb.area-sanda-hyogo.jp/toshow/asp/syousai_w.asp?TosCode=#{@id}"
  str = open(@url).read
  doc = Nokogiri::HTML(str, nil, 'cp932')

  # 書誌情報
  detail = doc.xpath('/html/body/table/tr/td/form/table[1]')

  index = rows_info_of_books(detail)

  @title = detail.css("tr[#{index[:title]}] td[2]").text
  @author = detail.css("tr[#{index[:author]}] td[2]").text
  @publisher = detail.css("tr[#{index[:publisher]}] td[2]").text
  @year = detail.css("tr[#{index[:year]}] td[2]").text
  @ndc = detail.css("tr[#{index[:ndc]}] td[2]").text
  @pages = detail.css("tr[#{index[:pages]}] td[2]").text
  @size = detail.css("tr[#{index[:size]}] td[2]").text
  @isbn = detail.css("tr[#{index[:isbn]}] td[2]").text
  @description = detail.css("tr[#{index[:description]}] td[2]").text

  @reserve_count = detail.xpath('//html/body/table/tr/td/form/table[2]/tr/td').text.gsub(/.*(\d).*/, "\\1").to_i
  @stocks = Array.new

  # すべて貸出中の場合と、在庫ありの場合はHTMLが違う。
  # 事前に在庫ありか貸出中かは判断できないため、
  # いったん在庫ありで試してダメなら、すべて貸出中のクエリーを投げる。
  xpath_if_all_lending = '//table[2]/tr[3]/td/table/tr'
  xpath_has_stock = '//table/tr/td/form/table[3]/tr[3]/td/table/tr'
  stock_node = doc.xpath(xpath_has_stock)
  if stock_node.empty?
    stock_node = doc.xpath(xpath_if_all_lending)
  end

  stock_node.each do |elem|
    title_elem = elem.css('th[1]')

    if title_elem.empty?
      stock = Hash.new
      stock[:library] = elem.css('td[2]').text
      stock[:location] = elem.css('td[3]').text
      stock[:ndc] = elem.css('td[4]').text
      stock[:code] = elem.css('td[5]').text
      stock[:classfication] = elem.css('td[6]').text
      stock[:lending] = elem.css('td[7]').text
      stock[:kintai] = elem.css('td[8]').text
      @stocks << stock
    end
  end
  @leftnav = "<a href='#{options.base_url}/'><img alt='home' src='#{options.base_url}/images/home.png' /></a>"

  @base_url = options.base_url

  erb :book
end
