defmodule RustDateTime do
  use Rustler, otp_app: :api_web, crate: "rustdatetime"

  # When your NIF is loaded, it will override this function.
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  def unix_to_local(_unix), do: :erlang.nif_error(:nif_not_loaded)
end
