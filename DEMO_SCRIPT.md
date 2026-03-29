# Hecks Demo Script — 15 Minutes

> Generated from [hecks_docs/narrative.md](hecks_docs/narrative.md).
> Same story, with timing markers and presenter notes.

---

## Act 1: Sketch & Play (0:00–3:00)

### [0:00] Hook

> "Hecks is a domain compiler. Describe your business once, generate complete applications in Ruby, Go, or Rails. It's AI-native — let me show you."

```bash
$ gem install hecks
$ hecks mcp
```

> "Hecks ships with an MCP server. Claude can model domains alongside you."

### [0:30] Sketch

```bash
$ hecks new blog
$ cd blog
$ hecks console
```

```ruby
hecks(sketch)> Post
created Post

hecks(sketch)> Post.title String
added attribute title to Post

hecks(sketch)> Post.status String
added attribute status to Post

hecks(sketch)> Post.lifecycle :status, default: "draft"
added lifecycle on status, default: draft

hecks(sketch)> Post.transition "PublishPost" => "published"
added transition PublishPost → published

hecks(sketch)> Post.transition "ArchivePost" => "archived"
added transition ArchivePost → archived

hecks(sketch)> Post.create
created CreatePost

hecks(sketch)> Post.create.title String
added attribute title to CreatePost → CreatedPost
```

### [1:30] Comments

```ruby
hecks(sketch)> Comment
created Comment

hecks(sketch)> Comment.post_id reference_to("Post")
added reference post_id → Post

hecks(sketch)> Comment.author String
added attribute author to Comment

hecks(sketch)> Comment.body String
added attribute body to Comment

hecks(sketch)> Comment.create
created CreateComment

hecks(sketch)> Comment.create.post_id reference_to("Post")
added reference post_id → Post

hecks(sketch)> Comment.create.author String
added attribute author to CreateComment

hecks(sketch)> Comment.create.body String
added attribute body to CreateComment → CreatedComment
```

### [2:00] Play

```ruby
hecks(sketch)> play!
hecks(play)> Post.create(title: "Hello World")
```

> Output: `CreatedPost { title: "Hello World", status: "draft" }`

```ruby
hecks(play)> Post.publish(post_id: Post.all.first.id)
```

> Output: `PublishedPost { status: "published" }`

### [2:30] Save

```ruby
hecks(play)> export
```

> "That wrote our hecks_domain.rb. This is the source of truth."

---

## Act 2: Web Explorer (3:00–4:30)

### [3:00] Serve

```ruby
hecks(play)> serve!
```

> "Let's play like a human. This is the web explorer."

### [3:10] Browser

- Navigate to `http://localhost:9292`
- Create a post via the form
- Lifecycle badge: "draft" → click Publish → "published"
- Create a comment — Post dropdown shows your posts
- Show the event log

> "Notice: domain events, not framework events. CreatedPost. PublishedPost. This is your ubiquitous language."

---

## Act 3: Claude Takes Over (4:30–7:00)

### [4:30] Photos

> "Let Claude drive."

Tell Claude:

> "Build me a photo gallery domain. Photos have a title, url, taken_at date, and tags. I need upload, tag, and archive commands."

Claude generates via MCP. Output shows each aggregate created.

### [5:00] Promote Comments

> "Wouldn't it be nice if both apps shared comments?"

Tell Claude:

> "Promote Comments into its own domain. Wire it into both Blog and Photos."

### [5:30] Cross-domain policy

> "When I upload a photo, I want a draft blog post."

Claude adds:

```ruby
policy "AutoDraft" do
  on "UploadedPhoto"
  trigger "CreateDraftPost"
  map title: :title
end
```

> "One policy. Three domains. Upload a photo, a draft post appears."

### [6:00] Show it

- Multi-domain explorer — nav grouped by domain
- Upload a photo
- Event log: `UploadedPhoto → AutoDraft → CreatedDraftPost`
- Draft post appeared in Blog

### [6:30] Wiring

- Config page → wiring diagram
- Events flowing between bounded contexts

---

## Act 4: Extend (7:00–9:00)

### [7:00] Persistence

> "Everything is in memory. Let's fix that."

```ruby
extend :sqlite
```

### [7:15] Multitenancy

> "Oops, we need multitenancy."

```ruby
extend :tenancy
```

### [7:30] Scale

> "Oops, hotcakes. Real database."

```ruby
extend :postgres
```

### [7:45] Slack

> "Developers want notifications."

```ruby
extend :slack, webhook: ENV["SLACK_URL"]
```

### [8:00] Queue

> "Acquired. They need our events in real time."

```ruby
extend :queue, adapter: :rabbitmq
```

> "Each one is one line. No reboot. When you're happy, `export` captures everything."

---

## Act 5: Go (9:00–10:30)

### [9:00] Build

> "The acquiring company uses Go. Let's generate a Go app."

```bash
$ hecks build --target go
$ ./blog serve 9292
```

### [9:30] Same explorer

- Open browser — same forms, same badges, same domain
- Create a post, publish it, add a comment

> "Same domain. Single binary. Day one productive."

### [10:00] Versioning

> "Two languages, one domain. We need to keep apps from breaking."

```bash
$ hecks diff
```

> Show breaking change detection.

---

## Act 6: The Real Thing (10:30–12:00)

### [10:30] Pitch

> "Blog, comments, photos — this has been done."
>
> "I tried asking Claude to build a complex app with DDD and hexagonal architecture. If you've tried this, you know it didn't go well. Claude doesn't have an opinion. Hecks does. Convention over configuration."

### [11:00] Governance explorer

- Nav grouped by domain: Compliance, Identity, Model Registry, Operations, Risk Assessment
- Create a policy → activate → lifecycle badge
- Cross-domain reference dropdowns
- Direct-action buttons — Suspend, Retire, one click

> "You build your own app on top. The explorer proves the domain works."

### [11:30] Event log + wiring diagram

---

## Act 7: Rails & Sinatra (12:00–13:30)

### [12:00] Rails

> "This one's for my family."

```bash
$ hecks build --target rails
$ rails server
```

> "Hecks on Rails!"

Show the controller:

```ruby
class PostsController < ApplicationController
  def create
    Post.create(title: params[:title], body: params[:body])
  end
end
```

Show the form:

```erb
<%= form_with model: @post do |f| %>
  <%= f.text_field :title %>
  <%= f.text_area :body %>
  <%= f.submit %>
<% end %>
```

> "Hecks handles the domain. Rails handles the web. No ActiveRecord."

### [13:00] Sinatra

```ruby
require "sinatra"
require "blog_domain"

post "/posts" do
  Post.create(title: params[:title], body: params[:body])
  redirect "/posts"
end
```

> "Same domain. Ten lines. Pick your framework."

---

## Act 8: Close (13:30–15:00)

### [13:30] Recap

> "Here's what we just did in 15 minutes:
>
> - Sketched a domain in a REPL
> - Played with live objects
> - Served a web explorer with forms, lifecycle badges, and event logs
> - Had Claude add a photo gallery and wire shared comments
> - Extended with sqlite, tenancy, postgres, slack, rabbitmq — one line each
> - Generated a Go binary from the same domain
> - Generated a Rails app and a Sinatra app
> - Showed a 14-aggregate governance platform Claude built in minutes
>
> One DSL. Multiple targets. Zero runtime dependency."

### [14:30] Close

```bash
$ gem install hecks
```

> "Star the repo. Try the REPL. Ask Claude to build you something."

---

## Pre-demo checklist

- [ ] `gem uninstall hecks` (fresh install moment)
- [ ] Governance app running at `examples/governance/`
- [ ] Go toolchain installed
- [ ] Claude Code with hecks MCP configured
- [ ] Terminal font ≥ 18pt
- [ ] Browser bookmark for localhost:9292
- [ ] Slack webhook in env (or mock)
- [ ] Screen recording running

## Required stories

- [HEC-264](https://linear.app/hecks/issue/HEC-264) — Promote aggregate into own domain
- [HEC-265](https://linear.app/hecks/issue/HEC-265) — REPL immediate feedback
- [HEC-266](https://linear.app/hecks/issue/HEC-266) — `serve!` from REPL
- [HEC-267](https://linear.app/hecks/issue/HEC-267) — `export` saves to file
- [HEC-268](https://linear.app/hecks/issue/HEC-268) — MCP visible output
- [HEC-269](https://linear.app/hecks/issue/HEC-269) — Multi-domain explorer
- [HEC-270](https://linear.app/hecks/issue/HEC-270) — `extend` at runtime
- [HEC-271](https://linear.app/hecks/issue/HEC-271) — `hecks build --target go`
- [HEC-272](https://linear.app/hecks/issue/HEC-272) — `hecks build --target rails`
- [HEC-273](https://linear.app/hecks/issue/HEC-273) — `hecks diff`
- [HEC-274](https://linear.app/hecks/issue/HEC-274) — `extend :slack`
- [HEC-275](https://linear.app/hecks/issue/HEC-275) — `extend :queue`
- [HEC-278](https://linear.app/hecks/issue/HEC-278) — Unify into `extend`
- [HEC-240](https://linear.app/hecks/issue/HEC-240) — Wiring diagram
- [HEC-262](https://linear.app/hecks/issue/HEC-262) — Event log page
