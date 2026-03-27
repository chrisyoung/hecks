# HecksGo::ErrorsGenerator
#
# Generates Go error types matching the hecks error hierarchy.
# All errors implement error interface and have JSON serialization.
#
module HecksGo
  class ErrorsGenerator
    def initialize(package:)
      @package = package
    end

    def generate
      <<~GO
        package #{@package}

        import "encoding/json"

        type ValidationError struct {
        \tField   string `json:"field"`
        \tMessage string `json:"message"`
        \tRule    string `json:"rule,omitempty"`
        }

        func (e *ValidationError) Error() string { return e.Message }

        func (e *ValidationError) AsJSON() []byte {
        \tb, _ := json.Marshal(e)
        \treturn b
        }

        type GuardRejected struct {
        \tCommand   string `json:"command"`
        \tAggregate string `json:"aggregate,omitempty"`
        \tMessage   string `json:"message"`
        }

        func (e *GuardRejected) Error() string { return e.Message }

        type PortAccessDenied struct {
        \tRole    string `json:"role"`
        \tAction  string `json:"action"`
        \tMessage string `json:"message"`
        }

        func (e *PortAccessDenied) Error() string { return e.Message }
      GO
    end
  end
end
