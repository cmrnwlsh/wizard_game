defmodule Tui do
  def start_link(opts \\ []), do: Tui.Supervisor.start_link(opts)
  defdelegate render(iodata), to: Tui.Renderer
  defdelegate size(), to: Tui.Terminal
  def shutdown(code \\ 0), do: System.stop(code)
end

defmodule Tui.Supervisor do
  use Supervisor

  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts) do
    [
      {Tui.Terminal, opts},
      {Tui.Renderer, opts},
      {Tui.Input, opts}
    ]
    |> Supervisor.init(strategy: :rest_for_one, max_restarts: 0)
  end
end
