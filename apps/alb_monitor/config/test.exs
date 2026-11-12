import Config

config :alb_monitor, ex_aws: FakeAws, req_options: [plug: {Req.Test, ALBMonitor.Monitor}]
