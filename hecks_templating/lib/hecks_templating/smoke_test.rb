# = HecksTemplating::SmokeTest
#
# Domain-driven HTTP smoke test for the web explorer. Exercises every
# generated page (home, index, show, form, config) against a running
# server. Works with both Ruby and Go targets since both produce the
# same HTTP routes.
#
#   smoke = HecksTemplating::SmokeTest.new("http://localhost:9292", domain)
#   results = smoke.run
#   results.select { |r| r[:status] == :fail }
#
require "net/http"
require "uri"
require "json"

module HecksTemplating
  class SmokeTest
    Result = Struct.new(:status, :method, :path, :http_code, :error, keyword_init: true)

    def initialize(base_url, domain)
      @base = base_url.chomp("/")
      @domain = domain
    end

    def run
      results = []
      results << check_get("/", "home")
      results << check_get("/config", "config")

      @domain.aggregates.each do |agg|
        plural = underscore(agg.name) + "s"
        agg_snake = underscore(agg.name)
        create_cmds, update_cmds = partition_commands(agg, agg_snake)

        results << check_get("/#{plural}", "#{agg.name} index")

        create_cmds.each do |cmd|
          cmd_snake = underscore(cmd.name)
          results << check_get("/#{plural}/#{cmd_snake}/new", "#{cmd.name} form")
          # Go uses /aggregate/command, Ruby static uses /aggregate/command/submit
          post_path = "/#{plural}/#{cmd_snake}"
          result = check_post(post_path, build_form_data(cmd), "#{cmd.name} submit")
          if result.http_code == 404
            result = check_post("#{post_path}/submit", build_form_data(cmd), "#{cmd.name} submit")
          end
          results << result
        end

        id = fetch_first_id(plural)
        if id
          results << check_get("/#{plural}/show?id=#{id}", "#{agg.name} show")
          update_cmds.each do |cmd|
            cmd_snake = underscore(cmd.name)
            results << check_get("/#{plural}/#{cmd_snake}/new?id=#{id}", "#{cmd.name} form")
          end
        end
      end

      print_results(results)
      results
    end

    private

    def partition_commands(agg, agg_snake)
      # Match any _id suffix that could refer to this aggregate
      # e.g., governance_policy_id, policy_id, governance_policy_id all match
      id_pattern = /_id$/
      creates = agg.commands.select { |c| c.attributes.none? { |a| a.name.to_s =~ id_pattern && a.name.to_s.end_with?("_id") && agg_snake.end_with?(a.name.to_s.sub(/_id$/, "")) } }
      updates = agg.commands - creates
      [creates, updates]
    end

    def build_form_data(cmd)
      cmd.attributes.each_with_object({}) do |a, h|
        h[a.name.to_s] = sample_value(a)
      end
    end

    def sample_value(attr)
      case attr.type.to_s
      when /Integer/ then "1"
      when /Float/   then "1.5"
      when /Date/    then "2026-01-01"
      when /Boolean/ then "true"
      else "test_#{attr.name}"
      end
    end

    def fetch_first_id(plural)
      uri = URI("#{@base}/#{plural}")
      req = Net::HTTP::Get.new(uri)
      req["Accept"] = "application/json"
      res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
      items = JSON.parse(res.body) rescue nil
      items&.first&.dig("id")
    rescue => e
      nil
    end

    def check_get(path, label)
      uri = URI("#{@base}#{path}")
      res = Net::HTTP.get_response(uri)
      body = res.body.to_s
      if res.code.to_i == 200 && !body.include?("Render error")
        Result.new(status: :pass, method: "GET", path: path, http_code: res.code.to_i)
      else
        error = body[/Render error[^<]*/] || "HTTP #{res.code}"
        Result.new(status: :fail, method: "GET", path: path, http_code: res.code.to_i, error: error)
      end
    rescue => e
      Result.new(status: :fail, method: "GET", path: path, http_code: 0, error: e.message)
    end

    def check_post(path, data, label)
      uri = URI("#{@base}#{path}")
      # Try JSON (Ruby static server), fall back to form-urlencoded (Go server)
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(data)
      res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
      code = res.code.to_i
      # If JSON rejected, try form-urlencoded
      if code >= 400
        res = Net::HTTP.post_form(uri, data)
        code = res.code.to_i
      end
      # 2xx = success, 3xx = redirect, 422 = validation error (expected for sample data)
      if (200..399).include?(code) || code == 422
        Result.new(status: :pass, method: "POST", path: path, http_code: code)
      else
        Result.new(status: :fail, method: "POST", path: path, http_code: code, error: res.body&.slice(0, 200))
      end
    rescue => e
      Result.new(status: :fail, method: "POST", path: path, http_code: 0, error: e.message)
    end

    def print_results(results)
      pass = results.count { |r| r.status == :pass }
      fail = results.count { |r| r.status == :fail }
      results.each do |r|
        icon = r.status == :pass ? "OK  " : "FAIL"
        line = "#{icon} #{r.method.ljust(4)} #{r.path}"
        line += " -- #{r.error}" if r.error
        puts line
      end
      puts "\n#{pass} passed, #{fail} failed (#{results.size} total)"
    end

    def underscore(str)
      str.to_s.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
         .gsub(/([a-z\d])([A-Z])/, '\1_\2')
         .downcase
    end
  end
end
