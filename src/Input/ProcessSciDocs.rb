#!/usr/bin/env ruby
# encoding: UTF-8

### 20/05/2014 - Ankur

require 'rubygems'
require 'optparse'
require 'json'
require 'optparse'
require 'pp'
require 'rexml/xpath'
require 'nokogiri'
require 'pathname'


def process_doc (source_file)
  f = File.open(source_file, "r:iso-8859-1:utf-8")
  doc = Nokogiri::XML(f)
  f.close

  # Initialize the array to store sections
  sections = Array.new

  block = doc.xpath('//variant/sectionHeader | //variant/bodyText').to_a.to_enum
  section = ""
  text = ""
  section_text = ""
  first = true
  begin
    while true
      sec = block.next
      if sec.name == 'sectionHeader'
        # If a new section is encoutered, then push the variables of the
        # previous section into the array 'sections'. The 'first' flag is used
        # to prevent this from happening at the first instance of section.
        if first
          first = false
        else
          sections.push({"section"=>section, "title"=>section_text, "text"=>text})
          text = ""
        end
        section = sec['genericHeader']
        section_text = sec.content.gsub(/\n/, '')
      else
        text << sec.content.gsub(/-\n/, '').gsub(/([^-])\n/, '\1 ').gsub(/^\n/, '')
      end
    end
  rescue StopIteration
  end

  # Note that the last section has not been included in the array 'sections'.
  # Ths is done assuming that the last section would be the References seciton
  # and hence is not required.
  # This could have been done by including it in the 'rescue' part of the code
  # and then filtering the array sections of the referecens.

  return sections
end

if __FILE__ == $0 then
  # Parse command line options
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: ./#{__FILE__} [options]"

    options[:file]  = nil
    opts.on( '-f', '--file FILE', 'Process a single file' ) do|file|
     options[:file] = file
    end

    options[:dir]  = nil
    opts.on( '-d', '--dir DIR', 'Process a corpus dir' ) do|dir|
     options[:dir] = dir
    end

    opts.on( '-h', '--help', 'Help to use the script' ) do
     puts opts
     exit
    end

  end.parse!

  if options[:file].nil? and options[:dir].nil?
    puts "No options entered. Please refer to the help (-h, --help) for how to run the script"
    exit
  end

  # Initialize the array to store documents
  documents = Array.new

  if options[:file]
    filepath = Pathname.new options[:file]
    documents.push({"document"=>filepath.basename, "content"=>process_doc(filepath)})
  elsif options[:dir]
    Dir.glob(options[:dir]+'/*.xml').each do |fn|
      filepath = Pathname.new fn
      documents.push({"document"=>filepath.basename, "content"=>process_doc(fn)})
    end
  end

  puts JSON.generate({"corpus"=>documents})
end
