ExUnit.start()

Path.wildcard("test/support/**/*.ex")
|> Enum.each(&Code.require_file/1)
