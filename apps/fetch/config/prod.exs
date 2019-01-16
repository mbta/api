use Mix.Config

config :fetch, FileTap,
  module: Fetch.FileTap.S3,
  # 8 MB
  max_tap_size: 8_388_608

config :fetch, FileTap.S3, bucket: {:system, "FETCH_FILETAP_S3_BUCKET"}
