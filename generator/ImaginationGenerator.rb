#!/usr/bin/env ruby

#
# ImaginationGenerator.rb
# Web scraper and image assembler for ImaginationSquared.com Deep Zoom
#
#     http://hostilefork.com/openzoom-squared/
#
# Hacked Together by The Hostile Fork (http://hostilefork.com)
# License: MPL 1.1/GPL 3/LGPL 3
#
# This script uses HTTP requests and DOM queries to get several images 
# and metadata about those images from the imaginationsquared.com website.
# It then produces a giant image from all of those images using RMagick,
# and then slices it for deep zooming.
#
# It is my first attempt at writing a Ruby program, and it was provoked by
# curiosity about the practical issues of the language as well as a desire
# to use some simple libraries for automation.  My goal was to learn the
# basics of how one would do web scraping, DOM processing, and programmatic
# image manipulation in Ruby... while completing a task that was satisfying
# another curiosity I had about the OpenZoom library.
#
# There may be value in generalizing this as a tool for people who have
# similar project needs.  Or it could be a learning tool for others.  Or,
# perhaps it will not be touched further once its original task has been
# finished.
#


######
# CONFIGURATION SETUP
###

# In case there is failure at any given step, the previous information
# is cached in a dir.  If you suspect errors or change the code, delete
# the relevant cache information...or the whole directory if you want
# to start the scrape & processing from scratch.

cachePath = 'cache/'
gridHtmlCachePath = cachePath + 'grid.html'
imagesCachePath = cachePath + 'images/'
giantImageCachePath = cachePath + 'allsquares.jpg'

# The output directory contains the information you should put alongside
# OpenZoomSquared.swf when it runs.  Currently it is handled just like
# the cache, in that if the file already exists it won't be created
# again.  This is for my convenience but a better dependency system
# could be worked out.

outputPath = 'allsquares/'
descriptorOutputPath = outputPath + 'squaresdescriptor.xml'
deepzoomOutputPath = outputPath + 'allsquares.dzi'

# Currently hardcoded metrics.  The values are written into the descriptor
# file, however, so that the player can work with changes in these values.
squareWidth = 300
squareHeight = 300
horizontalSpacing = 10
verticalSpacing = 10


######
# LIBRARY INCLUDES
###

# Network library for reading images and HTML off of imaginationsquared.com
require 'net/http'

# Ruby "gems" module is required for hpricot and RMagick 
require 'rubygems'

# Hpricot is a light HTML parser which lets you do jQuery style
# interactions, extracting the artist names and image properties
# off of the grid.html page and the pages for each artwork
require 'hpricot'

# RMagick is a ruby interface for Image Magick which lets you do
# image manipulations.  It's used by the deepzoom.rb file, but
# also here in imagination.rb to programmatically create a large
# grid from the many smaller images.
require 'RMagick'
include Magick

# This deep zoom Ruby file generates the proper thumbnails and is
# part of the OpenZoom project
require 'deepzoom'

# for cleaning up unescaped URIs
require 'uri'


######
# HELPER ROUTINES
###

# http://www.ruby-forum.com/topic/120436
def escapeXmlString(input)
   # all kinds of other processing of input simulated by the input.dup
   result = input.dup

   result.gsub!("&", "&amp;")
   result.gsub!("<", "&lt;")
   result.gsub!(">", "&gt;")
   result.gsub!("'", "&apos;")
   result.gsub!("\"", "&quot;")

   return result
end

# a first step toward a better factoring is to divide into phases
def scriptPhase(phase, path=nil)
  if (path != nil) and File::readable?(path) then
    puts 'SKIPPING: ' + phase
    puts '   (because ' + path + ' already exists.)'
  else
    puts 'START: ' + phase
    result = yield
    puts 'DONE.'
  end
  puts '-----'
  return result
end


######
# MAIN SCRIPT CODE
###

scriptPhase("Make cache path", cachePath) { Dir::mkdir(cachePath) }

scriptPhase("Fetch html from imaginationsquared.com", gridHtmlCachePath) do
  Net::HTTP.start('imaginationsquared.com') { |http|
    resp = http.get('/grid.html')
    open(gridHtmlCachePath, 'wb') { |file|
      file.write(resp.body)
    }
  }
end

gridHtmlText = scriptPhase('Cleanup html text before parse') do
  
  # Here's a hook where we can handle any problems in the grid.html
  # file with simple text operations, before it gets parsed.  (For
  # instance if the large format version of a piece of artwork
  # doesn't have a filename precisely derived from the thumbnails,
  # or if there is any missing information.)
  
  htmlText = File.read(gridHtmlCachePath)
  
  # the long way of doing string substition destructively

  htmlText = htmlText.sub('Yvonne_C._LozanoSM.jpg', 'Yvonne-C.-LozanoSM.jpg')
  
  # the shorter way of doing string substitution destructively!
  
  htmlText.sub!('peter_rumpelSM.jpg" alt=""', 'peter_rumpelSM.jpg" alt="Peter Rumpel"')
  
  htmlText # return
end

scriptPhase('Make image cache path', imagesCachePath) do
  Dir::mkdir(imagesCachePath)
end

numColumns, numRows, allSquares = scriptPhase('Parsing and extracting art metadata') do
  htmlRoot = Hpricot.parse(gridHtmlText)

  # grid.html file contains 912 <div> elements of class "square".
  # The first such div doesn't aElement to a painting or an artist bio:
  #
  # <div class="square">
  #     <a href="bios/col_111_to_col120/col113/The Grid.html">
  #        <imgElement src="Squares_images/col 111 to 120/col113/The-GridSM.jpg"
  #             alt="The Grid"
  #        >
  #     </a>
  # </div>
  #
  # But the other 911 <div> elements contain information for a picture,
  # except for a few "blank" ones.  They look like this:
  #
  # <div class="square">
  #     <a href="bios/col_111_to_col120/col112/Suvarna Shah.html">
  #         <imgElement src="Squares_images/col 111 to 120/col112/Suvarna-ShahSM.jpg"
  #              alt="Suvarna Shah"
  #         >
  #     </a>
  # </div>

  allSquares = []
  
  columnMaxes = {}
  row = 0
  column = 0
  columnOne = true
  
  htmlRoot.search('div').each do |divElement|
    if divElement.attributes['class'] == 'square' then
      divElement.search('a').each do |aElement|
	  imgElement = aElement.search('img').first
	  if imgElement.attributes['alt'] == 'The Grid' then
	    next
	  end
	  if imgElement.attributes['alt'] == 'blank' then
	    next
	  end
	  
	  # there are some incorrectly escaped URLs in grid.html as of 9-9-2010
	  # browsers turn spaces into %20 and such for you, but Ruby's http
	  # layer is lower level so we must URI.escape.  Also, we want the
	  # large version and not the thumbnail, so we take the "SM" off
	  # the name.
	  
	  src300x300jpg = URI.escape(imgElement.attributes['src'].sub('SM.jpg', '.jpg'))

	  # It's not entirely clear what the correspondence of the layout on the website
	  # is for rows and columns in the gallery arrangement i.e. as shown in this video
	  #
	  #     http://www.youtube.com/watch?v=I1KFmgwmJdo
	  #
	  # I'm assuming the column information in the URLs are more canonical 
	  # than the location on the page.  So the column number for the artwork
	  # comes from the part right before the file name, such as
	  #
	  #      'Squares_images/col_101_to_110/col103/Monica-MaysSM.jpg'
	  #
	  # Sometimes the COL is in uppercase.  And for some reason columns 1 and 2 are
	  # in the same directory as "col1and2pics", I just alternate which I put
	  # the image into.
	  
	  columnIndicator = src300x300jpg.downcase.split('/')[2]
	  if columnIndicator == 'col1and2pics' then
	    if columnOne then
	      column = 1
	    else
	      column = 2
	    end
	    columnOne = !columnOne
	  else
	    column = columnIndicator.sub('col','').to_i
	  end
	  
	  if columnMaxes.has_key?(column) then
	    row = columnMaxes[column] + 1
	    columnMaxes[column] = row
	  else
	    columnMaxes[column] = 1
	    row = 1
	  end
	    
	  allSquares += [{
	    :cachedImagePath => imagesCachePath + File::basename(src300x300jpg),
	    :artist => imgElement.attributes['alt'],
	    :url =>
	      'http://imaginationsquared.com/' + aElement.attributes['href'],
	    :row => row,
	    :column => column
	  }]
      end
    end
  end
  
  [columnMaxes.keys.max, columnMaxes.values.max, allSquares] # return
end
  
scriptPhase('Fetching 300x300 files for each artwork') do

  cacheCount = 0

  notifyCacheHitsAndReset = lambda do
    if cacheCount > 0 then
      puts 'Skipping ' + cacheCount.to_s + ' cached images in ' + imagesCachePath
      cacheCount = 0
    end
  end
  
  allSquares.each do |square|
    if not File::readable?(square[:cachedImagePath]) then
      notifyCacheHitsAndReset.call
      puts src300x300jpg + " => " + square[:cachedImagePath]
      Net::HTTP.start('imaginationsquared.com') { |http|
	resp = http.get('/' + src300x300jpg)
	open(square[:cachedImagePath], 'wb') { |file|
	  file.write(resp.body)
	}
      }
    else 
      cacheCount = cacheCount + 1
    end
  end
  
  notifyCacheHitsAndReset.call
end

scriptPhase('Make output path', outputPath) { Dir::mkdir(outputPath) }

scriptPhase('Generate squares descriptor xml', descriptorOutputPath) do
  
  # There is nothing particularly compelling about using XML format
  # for the data of the artists and their URLs, other than that
  # it is becoming more pervasive than comma-delimited text in terms
  # of "out of the box" libraries for ActionScript3 / etc.  See
  # my question on StackOverflow where I solicit better practices
  # than used here:
  #
  #     http://stackoverflow.com/questions/3692553/defining-an-xml-format-for-a-2d-array-grid-of-items-to-be-read-by-actionscript3
  #
  # The nice thing about formatting it this way (with "dummy" allSquares
  # for any unoccupied cells) is that it's easy to pick the right
  # square for a row and column, since it isn't a "sparse" 2D array.

  allSquares = allSquares.sort_by { |s| [s[:column], s[:row]] }
  File.open(descriptorOutputPath, 'w') do |file|
    file.puts '<?xml version="1.0" encoding="utf-8"?>'
    gridLine = '<grid'
    gridLine += ' numColumns="' + numColumns.to_s + '"' 
    gridLine += ' numRows="' + numRows.to_s + '"'
    gridLine += ' squareWidth="' + squareWidth.to_s + '"'
    gridLine += ' squareHeight="' + squareHeight.to_s + '"'
    gridLine += ' horizontalSpacing="' + horizontalSpacing.to_s + '"'
    gridLine += ' verticalSpacing="' + verticalSpacing.to_s + '"'
    gridLine += '>'

    file.puts gridLine
    
    row = 1
    column = 1
    indent1 = '  '
    indent2 = '    '
    allSquares.each do |square|
      if (row == 1) then
	file.puts indent1 + '<!-- Column #' + column.to_s + ' -->'
	file.puts indent1 + '<column>'
      end

      squareLine = '<square'
      if ((square[:row] == row) and (square[:column] == column)) then
	needsRedo = false

	if (square.has_key?(:artist)) then
	   squareLine += ' label="' + escapeXmlString(square[:artist]) + '"'
	end
	if (square.has_key?(:url)) then
	  squareLine += ' url="' + square[:url] + '"'
	end
      else
	needsRedo = true
      end
      squareLine += '/>'
      file.puts indent2 + squareLine
      if (row == numRows) then
	file.puts indent1 + '</column>'
	file.puts indent1 + ''
	row = 1
	column = column + 1
      else
	row = row + 1
      end
      if needsRedo then
	redo
      end
    end
    while (row <= numRows) do
      file.puts indent2 + '<square />'
      if (row == numRows) then
	file.puts indent1 + '</column>'
	file.puts indent1 + ''
      end
      row = row + 1
    end
    file.puts '</grid>'
  end  
end

scriptPhase('Sew together GIGANTIC image', giantImageCachePath) do  

  # Since we are already starting with image tiles, it would be more memory
  # efficient to modify the deepzoom.rb code base to use that tiling factor
  # in order to specifically work with the existing tiles instead of stitching
  # them up into a giant image and slicing it again.  But I increased the
  # virtual memory on my VM and it worked anyway in a reasonable amount
  # of time, so this saved effort.

  bigImage = Image.new(
	      (numColumns)*(squareWidth+horizontalSpacing),
	      (numRows)*(squareHeight+verticalSpacing))
  
  allSquares.each do |square|
    oneImage = ImageList.new(square[:filename]).first
    print '.'

    x = (square[:column] - 1) * (squareHeight + verticalSpacing)
    y = (square[:row] - 1) * (squareWidth + horizontalSpacing)

    if false then
      # This way uses too much memory... because it generates
      # an intermediate bigImage on each composition
      bigImage = bigImage.composite(oneImage, x, y, AtopCompositeOp)
    else 
      # This canvas-based alternative does not generate an intermediary
      # copy of our big image
      painter = Draw.new
      painter.composite(x, y, squareWidth, squareHeight, oneImage, AtopCompositeOp)
      painter.draw(bigImage)
    end
  end
  bigImage.write giantImageCachePath

  # Let go of the image reference so we can garbage collect
  bigImage.destroy!()
end

scriptPhase('Slice and dice into Deep Zoom format', deepzoomOutputPath) do
  
  # Getting this to work required making a couple of tweaks to deepzoom.rb 
  # because there are leaks in RMagick which have to be plugged if you are
  # going to be working with such huge files
  #
  #     http://stackoverflow.com/questions/958681/how-to-deal-with-memory-leaks-in-rmagick-in-ruby
  #
  # That means that when you return from save_cropped_image, you have to first
  # destroy the image with:
  #
  #     cropped.destroy!()
  #
  # And mysteriously, changing this:
  #
  #     image.resize(0.5)
  #
  # ...into this:
  #
  #     imageHalf = image.scale(0.5)
  #     image.destroy!()
  #     image = imageHalf
  #
  # ...helped get the process to run to completion.
  
  image_creator = ImageCreator.new
  image_creator.create(giganticImagePath, deepzoomPath)
end
