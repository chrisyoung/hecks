```ruby
irb(hecks):001> aggregate "Cat"
=> #<Cat (0 attributes, 0 commands)>

irb(hecks):002> _a.attr :name
  + attr :name, String
=> #<Cat (1 attributes, 0 commands)>

irb(hecks):003> _a.command("Adopt") { attribute :name, String }
  + command Adopt -> Adopted
=> #<Cat (1 attributes, 1 commands)>

irb(hecks):004> play!
Entering play mode

irb(hecks):005> cat = Cat.new(name: "Whiskers")
=> #<ScratchDomain::Cat @name="Whiskers">

irb(hecks):006> cat.adopt
Command: Adopt
  Event: Adopted
    name: "Whiskers"

irb(hecks):007> Cat.count
=> 1

irb(hecks):008> Cat.find(cat.id).name
=> "Whiskers"
```

Define a domain. Play with live objects. Persist to memory. All in the REPL.
