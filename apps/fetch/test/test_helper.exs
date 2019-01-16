ExUnit.start()
Application.ensure_all_started(:bypass)
{:ok, _pid} = Fetch.FileTap.MockTap.start_link()
