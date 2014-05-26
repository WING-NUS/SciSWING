#/usr/bin/ruby
# encoding: UTF-8

### 25/05/2014 - Ankur

# TODO: This script
# Numbers will not be considered while counting the tokens and hence should not
# be included in the logic as well just as stopwords.

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/..')
$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../..')

require 'rubygems'
require 'pp'
require 'json'
require 'fileutils'
require 'lib/ptb_tokenizer'
require 'Input/StopList'
require 'lib/stemmable'


def compute_word_counts document

  # This will calculate the term frequencies of all the words in the document.
  # To decide if this should include section counts as well or if that
  # should be a different function altogether. Also have to think about idf
  # from the webBase.
  term_freq = Hash.new
  document["content"].each do |section|
    section["sentences"].values
  end

end
