require 'net/http'
require 'nokogiri'
require 'sanitize'
require 'webrick'

# Example:
# https://request-fest.vercel.app/api?autosubmit=0&fetchhidden=1&action=https%3A%2F%2Fresults.finishtime.co.za%2Fresults.aspx%3FCId%3D35%26RId%3D4426%26EId%3D1%26dt%3D0%26adv%3D1&ctl00$edtSearch=&ctl00$edtSearch2=&ctl00$Content_Main$docount=0&ctl00$Content_Main$edtSearch=bellville&ctl00$Content_Main$cbGender=0&ctl00$Content_Main$cbCateg=0&ctl00$Content_Main$cbClub=All%20teams&ctl00$Content_Main$cbSort=0&ctl00$TrackerCode1=&ctl00$TrackerCode2=&__EVENTTARGET=ctl00%24Content_Main%24btnSearch

$ignored_parameters = ["action", "fetchhidden", "autosubmit"]

class Handler < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)

    auto_submit = !request.query.key?('autosubmit') or request.query['autosubmit'] == '1'

    form = generate_form(request, 'text', auto_submit)
    if not form
      response.status = 401
      response.body = "No action parameter"
    else
      response.status = 200
      response['Content-Type'] = 'text/html'
      response.body = form
    end
  end

  def do_POST(request, response)
    form = generate_form(request, 'hidden', true)
    if not form
      response.status = 401
      response.body = "No action parameter"
    else
      response.status = 200
      response['Content-Type'] = 'text/html'
      response.body = form
    end
  end

  def generate_form(request, input_type = 'text', auto_submit = false)
    action = request.query['action']
    if action
      form = "<form style=\"display: #{auto_submit ? 'none' : 'inline-block'};\" action=\"#{Sanitize.fragment(action.to_s)}\" method=\"post\">"

      if request.query['fetchhidden'] == '1'
        viewstate = get_hidden_inputs(action)
        if viewstate
          viewstate.each do |k,v|
            form += "#{Sanitize.fragment(k)}: <input type=\"#{input_type}\" name=\"#{Sanitize.fragment(k)}\" value=\"#{Sanitize.fragment(v)}\" /><br />"
          end
        end
      end

      request.query.each do |k,v|
        if $ignored_parameters.include?(k)
          form += "#{Sanitize.fragment(k)}: #{Sanitize.fragment(v)}<br />"
        else
          form += "#{Sanitize.fragment(k)}: <input type=\"#{input_type}\" name=\"#{Sanitize.fragment(k)}\" value=\"#{Sanitize.fragment(v)}\" /><br />"
        end
      end

      button_id = SecureRandom.uuid

      form += "<button style=\"display: #{auto_submit ? 'none' : 'inline-block'};\" id=\"#{button_id}\" type=\"submit\">Submit</button>"
      form += "</form>"
      if auto_submit
        form += "<script language=\"javascript\">"
        form += "document.getElementById(\"#{button_id}\").click();"
        form += "</script>"
      end

      return form
    else
      return false
    end
  end

  def get_hidden_inputs(action)
    uri = URI(action)
    response = Net::HTTP.get_response(URI.parse(action))

    if response.code != '200'
      return nil
    end

    r = {}
    begin
      html_doc = Nokogiri::HTML(response.body)

      hidden_inputs = html_doc.css('input[type=hidden]')

      hidden_inputs.each do |node| 
        r[node['name']] = node['value']
      end
    rescue => e
        r['class'] = e.class
        r['error'] = e.message
        r['backtrace'] = e.backtrace.join("\n")
    ensure
      return r
    end
  end
end
