defmodule SSHtTest do
  use ExUnit.Case
  doctest SSHt

  test "greets the world" do
    assert SSHt.hello() == :world
  end
end
