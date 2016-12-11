class BooksController < ApplicationController

  def index
    response = HTTParty.get('https://api.nytimes.com/svc/books/v3/lists.json?api-key=ec2d52743558402883a87a233a9b1af7&list=combined-print-and-e-book-fiction&date=2016-12-18')
    body = JSON.parse(response.body)

    @books = body["results"]
    @nps_scores = Array.new
    no_isbn_books = Array.new

    hydra = Typhoeus::Hydra.new
    @books.each_with_index do |book, index|
      # Check if book has isbn
      if book["isbns"].empty?
          no_isbn_books << index
          puts no_isbn_books
        next
      end

      # Create a request for each book
      request = Typhoeus::Request.new("https://www.goodreads.com/book/isbn/#{book["isbns"][0]["isbn13"].to_i}?key=Rf1LgjsOB2cf69K4gMbPkQ", followlocation: true)

      # Handle the requests
      request.on_complete do |response|
        if response.success?
          # Create a hash from the xml data and then symbolize it
          hash = Hash.from_xml(response.body.gsub("\n", ""))
          symbolized_hash = hash.symbolize_keys

          # Get data from
          data = symbolized_hash[:GoodreadsResponse]
          rating_dist = data["book"]["work"]["rating_dist"]

          split_rating = rating_dist.split('|')

          # Get total count and check if there are ratings
          total_count = split_rating[5].split(':')[1].to_i
          if total_count != 0
            promoter_count = 0.0
            detractor_count = 0.0

            # Get the count of 5 star ratings
            promoter_count = split_rating[0].split(':')[1].to_i

            # Get the count from 3 to 1 star ratings
            (2..4).each do |i|
              detractor_count += split_rating[i].split(':')[1].to_i
            end

            # Calculate percentages
            promoter_percentage = (promoter_count * 100) / total_count
            detractor_percentage = (detractor_count * 100) / total_count

            # Calculate nps score and append it
            nps_score = promoter_percentage - detractor_percentage
            @nps_scores << nps_score
          else
            @nps_scores << "This book has no ratings."
          end

        else
          @nps_scores << "Unable to get ratings :/"
        end
      end
      # Add each request to hydra queue
      hydra.queue(request)
    end
    # Run all the requests asynchronousyly
    hydra.run
  end

end
