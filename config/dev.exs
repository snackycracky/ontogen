import Config

config :ontogen,
  config_load_paths: [Path.join(__DIR__, "dev.ttl")],
  create_repo_id_file: :env
