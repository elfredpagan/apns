use Mix.Config
config :apns, :config,
  push_host: "api.push.apple.com",
  push_port: 443,
  key: "priv/key.pem",
  kid: "8HA4ZD58TK",
  app_id: "US6D8KGA6K",
  feedback_handler: APNS.FeedbackHandler
