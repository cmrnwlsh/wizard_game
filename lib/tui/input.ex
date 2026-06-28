defmodule Tui.Input do
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    state = %{
      subscriber: Keyword.get(opts, :subscriber),
      quit_keys: Keyword.get(opts, :quit_keys, [:ctrl_c]),
      reader: spawn_link(__MODULE__, :read_loop, [self()])
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:key, bytes}, state) do
    key = decode_key(bytes)

    if key in state.quit_keys do
      Tui.shutdown()
    else
      dispatch(state.subscriber, key)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, reader, reason}, %{reader: reader} = state) do
    Logger.debug("input reader stopped (#{inspect(reason)}); shutting down")
    Tui.shutdown()
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, %{reader: reader}) do
    if is_pid(reader) and Process.alive?(reader), do: Process.exit(reader, :kill)
    :ok
  end

  defp dispatch(nil, key), do: Logger.debug("key: #{inspect(key)}")
  defp dispatch(pid, key) when is_pid(pid), do: send(pid, {:tui_event, key})

  def read_loop(parent) do
    case IO.getn("", 1) do
      :eof ->
        :ok

      {:error, _reason} ->
        :ok

      bytes ->
        send(parent, {:key, bytes})
        read_loop(parent)
    end
  end

  def decode_key(<<3>>), do: :ctrl_c
  def decode_key("\d"), do: :backspace
  def decode_key("\r"), do: :enter
  def decode_key("\t"), do: :tab
  def decode_key("\e"), do: :escape
  def decode_key(other), do: other
end
