# PizzasDomain::Server::UI
#
# HTML UI helpers for the domain server. Provides a layout with navigation,
# and helper methods for rendering pages, tables, forms, and flash messages.
# No template engine — just Ruby strings.

module PizzasDomain
  module Server
    module UI
      def layout(title:, nav_items: [], &block)
        body = block.call
        nav_links = nav_items.map { |n| %(<a href="#{n[:href]}">#{n[:label]}</a>) }.join(" ")
        brand = title.split(" ").first
        css = "* { box-sizing: border-box; margin: 0; padding: 0; } " \
          "body { font-family: system-ui, -apple-system, sans-serif; background: #f5f5f5; color: #333; } " \
          "nav { background: #1a1a2e; padding: 1rem 2rem; display: flex; gap: 1.5rem; align-items: center; white-space: nowrap; } " \
          "nav a { color: #e0e0e0; text-decoration: none; font-weight: 500; flex-shrink: 0; } nav a:hover { color: #fff; } " \
          "nav .brand { color: #fff; font-weight: 700; font-size: 1.1rem; margin-right: 1rem; flex-shrink: 0; } " \
          ".container { max-width: 960px; margin: 2rem auto; padding: 0 1rem; } " \
          "h1 { margin-bottom: 1.5rem; color: #1a1a2e; } " \
          "table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.1); } " \
          "th { background: #1a1a2e; color: #fff; text-align: left; padding: 0.75rem 1rem; font-weight: 500; } " \
          "td { padding: 0.75rem 1rem; border-bottom: 1px solid #eee; } tr:hover td { background: #f8f8ff; } " \
          "a { color: #4361ee; } " \
          ".btn { display: inline-block; padding: 0.5rem 1rem; background: #4361ee; color: #fff; text-decoration: none; border-radius: 4px; border: none; cursor: pointer; font-size: 0.9rem; } " \
          ".btn:hover { background: #3a56d4; } .btn-sm { padding: 0.3rem 0.7rem; font-size: 0.8rem; } " \
          "form { background: #fff; padding: 1.5rem; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); max-width: 500px; } " \
          "label { display: block; margin-bottom: 0.3rem; font-weight: 500; font-size: 0.9rem; } " \
          "input, select { width: 100%; padding: 0.5rem; border: 1px solid #ddd; border-radius: 4px; margin-bottom: 1rem; font-size: 0.9rem; } " \
          "input:focus { outline: none; border-color: #4361ee; } " \
          ".flash { padding: 0.75rem 1rem; border-radius: 4px; margin-bottom: 1rem; } " \
          ".flash-success { background: #d4edda; color: #155724; } .flash-error { background: #f8d7da; color: #721c24; } " \
          ".detail { background: #fff; padding: 1.5rem; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); } " \
          ".detail dt { font-weight: 600; color: #666; font-size: 0.85rem; text-transform: uppercase; margin-top: 1rem; } " \
          ".detail dd { margin: 0.25rem 0 0 0; font-size: 1rem; } " \
          ".actions { margin-top: 1.5rem; display: flex; gap: 0.5rem; } " \
          ".mono { font-family: ui-monospace, monospace; font-size: 0.85rem; color: #666; }"

        js = "var _vRules={};" \
          "fetch('/_validations').then(function(r){return r.json()}).then(function(d){_vRules=d});" \
          "document.addEventListener('submit',function(e){" \
          "var f=e.target;if(f.tagName!=='FORM')return;" \
          "var action=f.getAttribute('action')||'';" \
          "var parts=action.split('/').filter(Boolean);" \
          "var key=parts.length>=3?(parts[0].charAt(0).toUpperCase()+parts[0].slice(1).replace(/s$/,''))+'/'+parts[1]:null;" \
          "if(!key||!_vRules[key])return;" \
          "var rules=_vRules[key];var ok=true;" \
          "f.querySelectorAll('.field-error').forEach(function(el){el.remove()});" \
          "Object.keys(rules).forEach(function(field){" \
          "var input=f.querySelector('[name='+field+']');if(!input)return;" \
          "var val=input.value;var r=rules[field];var msg=null;" \
          "if(r.presence&&(!val||val.trim()==='')){msg=field.replace(/_/g,' ')+\" can't be blank\"}" \
          "else if(r.positive&&val&&Number(val)<=0){msg=field.replace(/_/g,' ')+' must be positive'}" \
          "if(msg){ok=false;var err=document.createElement('div');err.className='field-error';" \
          "err.style.cssText='color:#c0392b;font-size:0.85rem;margin:-0.5rem 0 0.5rem';" \
          "err.textContent=msg;" \
          "input.parentNode.insertBefore(err,input.nextSibling);" \
          "input.style.borderColor='#c0392b'}});" \
          "if(!ok)e.preventDefault()});"

        "<!DOCTYPE html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'>" \
        "<title>#{brand}</title><style>#{css}</style></head><body>" \
        "<nav><span class='brand'>#{brand}</span>#{nav_links}</nav>" \
        "<div class='container'>#{body}</div>" \
        "<script>#{js}</script></body></html>"
      end

      def html_response(res, html)
        res["Content-Type"] = "text/html; charset=utf-8"
        res.body = html
      end

      def h(text)
        text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
      end
    end
  end
end
