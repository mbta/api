# StateMediator

**TODO: Add description**

## Installation

To use in another OTP app in this umbrella project

  1. Add `state_mediator` to your list of dependencies in `mix.exs`:

        def deps do
          [{:state, in_umbrella: true}]
        end

  2. Ensure `state_mediator` is started before your application:

        def application do
          [applications: [:state_mediator]]
        end
