module PagerApi
  module Pagination
    module WillPaginate

      def paginate(*args)
        options = args.extract_options!
        collection = args.first

        paginated_collection = paginate_collection(collection, options)

        options[:json] = paginated_collection

        options[:meta] = meta(paginated_collection, options) if PagerApi.include_pagination_on_meta?

        pagination_headers(paginated_collection) if PagerApi.include_pagination_headers?

        render options
      end

      private

        # Link: <http://example.com/api/v1/users?page="2">; rel="next",
        # <http://example.com/api/v1//users?page="5">; rel="last",
        # <http://example.com/api/v1//users?page="1">; rel="first",
        # <http://example.com/api/v1/users?page="1">; rel="prev",
        def pagination_headers(collection)
          links = (headers['Link'] || "").split(',').map(&:strip)
          clean_url = request.original_url.sub(/\?.*$/, '')

          paging_info = pages(collection)

          paging_info.each do |key, value|
            query_params = request.query_parameters.merge(page: value)
            links << %Q( <#{clean_url}?#{query_params.to_param}>; rel="#{key}" )
          end

          headers['Link'] = links.join(", ") unless links.empty?
          headers[PagerApi.total_count_header] = collection.total_pages

          return nil
        end

        def pagination_links(collection)
            current_uri = request.env['PATH_INFO']
            meta_links = {}

            pages(collection).each do |key, value|
              query_params = request.query_parameters.merge(page: value)
              meta_links[key] = "#{current_uri}?#{query_params.to_param}"
            end

            meta_links
        end

        def pages(collection)
          {}.tap do |paging|
            paging[:first] = 1
            paging[:last] = collection.total_pages
            paging[:current] = collection.current_page

            paging[:prev] = collection.current_page - 1 unless collection.current_page == 1
            paging[:next] = collection.current_page + 1 unless collection.current_page >= collection.total_pages
          end
        end

        def paginate_collection(collection, options = {})
          options[:page] = params[:page] || 1
          options[:per_page] = options.delete(:per_page) || params[:per_page]

          collection.paginate(options)
        end

        def meta(collection, options = {})
          {
            pagination:
            {
              per_page: options[:per_page] || params[:per_page] || ::WillPaginate.per_page,
              total_pages: collection.total_pages,
              total_objects: collection.total_entries,
              links: pagination_links(collection)
            }
          }
        end
    end
  end
end
