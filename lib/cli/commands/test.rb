module Hecks
  class CLI < Thor
    desc 'test','Regenerate the examples and run the specs'
    def test
      exec(
        (
          reset_example('soccer_season') +
          reset_example('pizza_builder') +
          ['rspec -f d']
        ).join("&&")
      )
    end

    private

    def reset_example(name)
      [
        "cd spec/examples/#{name}",
        'rm -rf lib',
        'rm -rf spec',
        'hecks generate:domain',
        'cd ../../..'
      ]
    end
  end
end