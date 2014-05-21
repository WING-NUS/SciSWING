#/usr/bin/ruby
# encoding: UTF-8

### 20/05/2014 - Ankur

require 'graph-rank'
require 'treat'
require 'json'
require 'time'

class SentenceRanker < GraphRank::TextRank

  StopWords = Treat.languages.english.stop_words

  def initialize
    @ranking = GraphRank::PageRank.new(0.85, 0.1, 50)
  end

  def run(text, n=3)
    @n, @text = n, text
    @features = @text.groups
    build_graph
    calculate_ranking
  end

  def build_graph
    @features.each do |grp|
      wc = grp.word_count
      @features.each do |grp2|
        wc2 = grp2.word_count
        add_ranking(grp, grp2, wc, wc2)
      end
    end
  end

  def add_ranking(grp, grp2, wc, wc2)
    score = 0.0
    grp.each_word do |wrd|
      next if StopWords.include?(wrd.to_s)
      grp2.each_word do |wrd2|
        score += 1 if wrd.stem == wrd2.stem
      end
    end
    score /= (Math.log(wc) + Math.log(wc2))
    @ranking.add(grp.id, grp2.id, score)
  end

  def calculate_ranking
    rankings = @ranking.calculate
    rankings = rankings[0..@n].map(&:first)
    @text.groups.select do |grp|
      rankings.include?(grp.id)
    end.map(&:to_s)
  end

end

include Treat::Core::DSL

ARGF.each do |l_JSN|

  # For each document, get all the sentences and put them in a temp file. This
  # temp file will then be used by 'treat' as input on which tokenization and
  # segmentaiton would be done after which the sentences would be ranked.
  $g_JSON = JSON.parse l_JSN
  $g_JSON["corpus"].each do |l_Article|

    all_sentences = []
    l_Article["content"].each do |section|
      all_sentences.push section["sentences"].values
    end
    temp_file = '/tmp/temp.'+rand.to_s
    File.open(temp_file, 'w') do |f|
      f.puts all_sentences.join("\n")
    end

    # Create a document using Treat
    doc = document "#{temp_file}"
    doc.apply(:chunk, :segment, :tokenize)

    #Initialize Ranking module
    stime = Time.now
    text_rank = SentenceRanker.new
    etime = Time.now
    puts "Time taken to build the graph : #{(etime - stime)}"
    stime = Time.now
    summary = text_rank.run(doc, 15)
    etime = Time.now
    puts "Time taken to rank the graph : #{(etime - stime)}"
    l_Article["top_sentences"] = Hash.new
    summary.each_with_index { |item, index|
      l_Article["top_sentences"][index] = item
    }

  end

  puts JSON.generate $g_JSON
end
