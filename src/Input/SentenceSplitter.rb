#/usr/bin/ruby
# encoding: UTF-8

### Ankur

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/..')
$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../..')

require 'rubygems'
require 'pp'
require 'json'
require 'fileutils'

$project_dir = "/home/ankur/devbench/scientific/SciSWING"

# Reads JSON from ProcessSciDocs.rb and adds splitted_sentences field to the json"
# Please note that SWING preserves the original json data given as input and
# appends a new array of with the key 'splitted_sentences' that contains the
# corpus data with the sentences splitted.
# However, in the interest of processing time and memory, here the original
# json will not be preserved. The 'text' component of each doc will be replaced
# with the splitted sentences.

def sentence_breaker(text)
    temp_file = '/tmp/temp.'+rand.to_s
    File.open(temp_file, 'w') do |f|
    f.puts text
    end
    `#{$project_dir}/lib/duc2003.breakSent/breakSent-multi.pl #{temp_file}`
    lines=File.readlines temp_file
    FileUtils.rm(temp_file)
    return lines

end


ARGF.each do |l_JSN|

  $g_JSON = JSON.parse l_JSN
  $g_docArray = []

  doc_num=0
  $g_JSON["corpus"].each do |l_Article|
    l_Article["doc_id"] = doc_num
    l_Article["actual_doc_id"] = l_Article["document"]
    l_Article.delete("document")
    # The sentences will be numbered for the entire document.
    sent_num=0
    l_Article["content"].each do |section|
      splt_sents = sentence_breaker section["text"]
      sentences = {}
      splt_sents.to_enum.with_index(sent_num).each do |sentence, idx|
        sentences[idx] = sentence.strip
      end
      section["sentences"] = sentences
      sent_num += splt_sents.length
      section.delete("text")
    end
    doc_num += 1
  end
end

puts JSON.pretty_generate $g_JSON
