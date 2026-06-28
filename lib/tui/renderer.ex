defmodule Tui.Renderer do
  use GenServer
  alias IO.ANSI

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def render(iodata) do
    GenServer.cast(__MODULE__, {:render, iodata})
  end

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_cast({:render, iodata}, state) do
    IO.write(iodata)
    {:noreply, state}
  end
end
