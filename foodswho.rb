require 'nokogiri'
require 'open-uri'
require 'csv'
require 'pry'

class Foodswho
  attr_reader :urls
  SEARCH_TANKI = 'http://foodswho.co.jp/search?q=%E7%9F%AD%E6%9C%9F'
  FOODSWHO = 'http://foodswho.co.jp'

  def initialize
    @urls = CSV.read('./tanki.csv').flatten
    return unless urls.empty?
    docs = [document(SEARCH_TANKI)]
    docs << pagination_urls(docs.first).map { |url| document(url) }
    docs.flatten!
    @urls = []
    urls << docs.map { |doc| parse_tanki_urls(doc) }
    urls.flatten!
    urls.each { |url| CSV.open('./tanki.csv', 'ab') { |csv| csv << [url] } }
  end

  def execute
    return if urls.empty?
    CSV.open('./tanki-results.csv', 'ab') do |csv|
      urls.each do |url|
        result = parse_content(document(url))
        csv << result unless result.nil?
      end
    end
    # result_file = File.open('./tanki-result.csv', 'ab')
  end

  def extract_term_code
    csv = CSV.read('./tanki-results.csv') rescue []
    if csv.empty?
      p "Run TankiCrawl#execute first"
      return
    end

    CSV.open('./tanki-results-2.csv', 'ab') do |line|
      csv.each do |row|
        line << row.push(*(extract_tanki_phrase(row)))
      end
    end
  end

  private

  def term_code(matched_array)
    return if matched_array.empty?
    day, week, month = matched_array.map(&:to_i)
    case
    when day == 1
      0
    when day > 1 && day < 6
      1
    when week == 1
      1
    when week > 1 && week < 4
      2
    when month == 1
      2
    else
      nil
    end
  end

  def extract_tanki_phrase(row)
    row.map do |text|
      parse = text.match(/(\d+)日.*短期|(\d+)週間.*短期|(\d+)ヶ月.*短期/)
      next if parse.nil?
      term_code = term_code(parse.captures)
      next if parse.to_s.size > 15 || term_code.nil?
      [
        parse.to_s,
        term_code
      ]
    end.compact.flatten
  end

  def parse_content(document)
    [
      document.xpath("//div[@class='job_title_caption']/h2").text,# Job title
      document.xpath("//dd/div[@class='job_times']/following-sibling::p").map(&:text),# Job working time
      document.xpath("//div[@id='job_pr']").text # Job Pr
    ] rescue nil
  end

  def parse_tanki_urls(document)
    document.xpath("//div[@class='search_btn']/a/@href").map(&:value) || []
  end

  def pagination_urls(document)
    document.xpath("//ul/li/a/@href").map(&:value)
      .select { |url| url[/search\/p\d/] }.uniq.map { |url| "#{FOODSWHO}#{url}" }
  end

  def document(url)
    Nokogiri::HTML(open(url))
  end
end

Foodswho.new.execute
Foodswho.new.extract_term_code

