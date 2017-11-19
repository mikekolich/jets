class Jets::Controller
  autoload :Renderers, "jets/controller/renderers"

  module Rendering
    def ensure_render
      return @rendered_data if @rendered

      # defaults to rendering templates
      Renderers::TemplateRenderer.new(self, default_options).render
    end

    # Many different ways to render:
    #
    #  render "articles/index", layout: "application"
    #  render :new
    #  render template: "articles/index", layout: "application"
    #  render json: {my: "data"}
    #  render text: "plain text"
    def render(options={}, rest={})
      raise "DoubleRenderError" if @rendered

      if options.is_a?(Symbol) or options.is_a?(String)
        options = normalize_options(options, rest)
      end

      options.reverse_merge!(default_options)

      @rendered_data =
        if options.key?(:template)
          Renderers::TemplateRenderer.new(self, options).render
        elsif options.key?(:json)
          Renderers::JsonRenderer.new(self, options).render
        elsif options.key?(:file)
          Renderers::FileRenderer.new(self, options).render
        elsif options.key?(:plain)
          Renderers::PlainRenderer.new(self, options).render
        else
          raise "Unsupported render options. options: #{options.inspect}"
        end

      @rendered = true
      @rendered_data
    end

    def default_options
      { layout: self.class.layout }
    end

    # Can normalize the options when it is a String or a Symbol
    # Also set defaults here like the layout
    def normalize_options(options, rest)
      template = options.to_s
      rest.merge(template: template)
    end

    # redirect_to "/posts", :status => 301
    # redirect_to :action=>'atom', :status => 302
    def redirect_to(url, options={})
      unless url.is_a?(String)
        raise "redirect_to url parameter must be a String. Please pass in a string"
      end

      uri = URI.parse(url)
      # if no location.host, we been provided a relative host
      if !uri.host && headers["origin"]
        url = "/#{url}" unless url.starts_with?('/')
        url = add_stage_name(url)
        redirect_url = headers["origin"] + url
      else
        redirect_url = url
      end

      aws_proxy = Renderers::AwsProxyRenderer.new(self,
        status: options[:status] || 302,
        headers: { "Location" => redirect_url },
        body: "",
        isBase64Encoded: false,
      )
      resp = aws_proxy.render
      # redirect is a type of rendering
      @rendered = true
      @rendered_data = resp
    end

    # Add API Gateway Stage Name
    def add_stage_name(url)
      if headers["origin"]
        host = headers["origin"]  # with http(s) scheme
        if host.include?("amazonaws.com") && url.starts_with?('/')
          stage_name = [Jets.config.short_env, Jets.config.env_extra].compact.join('_').gsub('-','_') # Stage name only allows a-zA-Z0-9_
          url = "/#{stage_name}#{url}"
        end
      end

      url
    end

  end
end