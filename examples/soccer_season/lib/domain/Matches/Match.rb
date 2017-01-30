module SoccerSeason
  module Domain
    module Matches
      class Match
        attr_accessor :fixture, :result, :pitch, :goals, :teams, :id
        def initialize(fixture:, result:, pitch:, goals:, teams:, id:)
        @fixture = Fixture.new(fixture)
@result = Result.new(result)
@pitch = PitchReference.new(pitch)
@goals = Goal.factory(goals)
@teams = Team.factory(teams)
@id = id
        end

        def to_json
          JSON.generate(fixture: fixture, result: result, pitch: pitch, goals: goals, teams: teams, id: id)
        end
      end
    end
  end
end
