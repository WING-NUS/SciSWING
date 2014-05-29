#/usr/bin/ruby
# encoding: UTF-8

### 20/05/2014 - Ankur

require 'graph-rank'
require 'treat'
require 'json'
require 'time'

class SentenceRanker < GraphRank::TextRank

  StopWords = Treat.languages.english.stop_words

  def initialize(all_sentences, n=4)
    @ranking = GraphRank::PageRank.new(0.85, 0.1, 50)
    @sentences, @n = all_sentences, n
    build_graph
  end

  def build_graph
    @sentences.each do |id1 , sent1|
      s1 = sentence sent1
      s1.apply(:tokenize)
      wc = s1.word_count
      @sentences.each do |id2, sent2|
        score = 0.0
        s2 = sentence sent2
        s2.apply(:tokenize)
        s1.each_word do |wrd|
          next if StopWords.include?(wrd.to_s)
          s2.each_word do |wrd2|
            score += 1 if wrd.stem == wrd2.stem
          end
        end
        wc2 = s2.word_count
        score /= (Math.log(wc) + Math.log(wc2))
        @ranking.add(id1, id2, score)
      end
    end
  end

  def calculate_ranking
    rankings = @ranking.calculate
    rankings = rankings[0..@n].map(&:first)
    @ranked_sents = Hash.new
    rankings.each_with_index { |id, index|
      @ranked_sents[index + 1] = { :id=>id, :sentence=>@sentences[id] }
    }
    return @ranked_sents
  end

end

include Treat::Core::DSL

ARGF.each do |l_JSN|

  # For each document, get all the sentences and put them in a temp file. This
  # temp file will then be used by 'treat' as input on which tokenization and
  # segmentaiton would be done after which the sentences would be ranked.
  $g_JSON = JSON.parse l_JSN
  $g_JSON["corpus"].each do |l_Article|

    all_sentences = Hash.new
    l_Article["content"].each do |section|
      all_sentences.merge! section["sentences"]
    end

    # Initialize Ranking module
    #stime = Time.now
    text_rank = SentenceRanker.new(all_sentences, 15)
    #etime = Time.now
    #puts "Time taken to build the graph : #{(etime - stime)}"
    #stime = Time.now
    summary = text_rank.calculate_ranking
    #etime = Time.now
    #puts "Time taken to rank the graph : #{(etime - stime)}"
    l_Article["top_sentences"] = summary

  end

  puts JSON.pretty_generate $g_JSON
end
