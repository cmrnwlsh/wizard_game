defmodule WizardGameTest do
  use ExUnit.Case
  doctest WizardGame

  test "greets the world" do
    assert WizardGame.hello() == :world
  end
end
