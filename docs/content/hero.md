```ruby
scratch(define):001> aggregate "Cat"
=> #<Cat (0 attributes, 0 commands)>

scratch(define):002> _a.attr :name
scratch(define):003> _a.command("Adopt") { attribute :name }
  + command Adopt -> Adopted

scratch(define):004> play!

scratch(play):005> cat = Cat.new(name: "Whiskers")
scratch(play):006> cat.adopt
Command: Adopt
  Event: Adopted
    name: "Whiskers"

scratch(play):007> Cat.count
=> 1

scratch(play):008> cat.name = "Sir Whiskers"
scratch(play):009> cat.adopt
Command: Adopt
  Event: Adopted
    name: "Sir Whiskers"

scratch(play):010> cat.reset!
scratch(play):011> cat.name
=> "Whiskers"
```
