```ruby
hecks(scratch define)> aggregate "Cat"
=> #<Cat (0 attributes, 0 commands)>

hecks(scratch define)> _a.attr :name
hecks(scratch define)> _a.command("Adopt") { attribute :name }
  + command Adopt -> Adopted

hecks(scratch define)> play!

hecks(scratch play)> cat = Cat.new(name: "Whiskers")
hecks(scratch play)> cat.adopt
Command: Adopt
  Event: Adopted
    name: "Whiskers"

hecks(scratch play)> Cat.count
=> 1

hecks(scratch play)> cat.name = "Sir Whiskers"
hecks(scratch play)> cat.adopt
Command: Adopt
  Event: Adopted
    name: "Sir Whiskers"

hecks(scratch play)> cat.reset!
hecks(scratch play)> cat.name
=> "Whiskers"
```
