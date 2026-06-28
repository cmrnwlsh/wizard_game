defmodule Tui.Terminal do
  use GenServer
  require Logger
  alias IO.ANSI

  @enter_alt_screen "\e[?1049h"
  @leave_alt_screen "\e[?1049l"
  @hide_cursor "\e[?25l"
  @show_cursor "\e[?25h"
  @signal_handler {__MODULE__.SignalForwarder, :tui_terminal}

  @resize_debounce_ms 50

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def size() do
    with {:ok, cols} <- :io.columns(),
         {:ok, rows} <- :io.rows() do
      {:ok, {cols, rows}}
    else
      _ -> {:error, :enotsup}
    end
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    case :shell.start_interactive({:noshell, :raw}) do
      :ok ->
        install_signal_handlers()
        IO.write([@enter_alt_screen, @hide_cursor, ANSI.clear()])

        state = %{
          subscriber: Keyword.get(opts, :subscriber),
          size: current_size(),
          resize_timer: nil
        }

        {:ok, state, {:continue, :announce_initial_size}}

      {:error, :already_started} ->
        {:stop, {:cannot_enter_raw_mode, "a shell is already interactive"}}

      {:error, reason} ->
        {:stop, {:cannot_enter_raw_mode, reason}}
    end
  end

  @impl true
  def handle_info({:signal, :sigwinch}, state) do
    if state.resize_timer, do: Process.cancel_timer(state.resize_timer)
    timer = Process.send_after(self(), :resize_settled, @resize_debounce_ms)
    {:noreply, %{state | resize_timer: timer}}
  end

  def handle_info(:resize_settled, state) do
    new_size = current_size()

    if new_size != state.size and new_size != nil do
      notify_resize(state.subscriber, new_size)
      {:noreply, %{state | size: new_size, resize_timer: nil}}
    else
      {:noreply, %{state | resize_timer: nil}}
    end
  end

  def handle_info({:signal, signal}, state) when signal in [:sigint, :sigterm] do
    Tui.shutdown()
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def handle_continue(:announce_initial_size, state) do
    notify_resize(state.subscriber, state.size)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    IO.write([@show_cursor, @leave_alt_screen])
    # :shell.start_interactive({:noshell, :cooked})
    :gen_event.delete_handler(:erl_signal_server, @signal_handler, :remove)
    :ok
  end

  defp install_signal_handlers() do
    enable_sigwinch()
    :os.set_signal(:sigint, :handle)
    :os.set_signal(:sigterm, :handle)
    :gen_event.delete_handler(:erl_signal_server, @signal_handler, :remove)
    :ok = :gen_event.add_handler(:erl_signal_server, @signal_handler, self())
  end

  defp current_size do
    case size() do
      {:ok, size} -> size
      {:error, _} -> nil
    end
  end

  defp notify_resize(nil, _size), do: :ok
  defp notify_resize(_pid, nil), do: :ok
  defp notify_resize(pid, size) when is_pid(pid), do: send(pid, {:tui_resize, size})

  defp enable_sigwinch do
    :os.set_signal(:sigwinch, :handle)
  rescue
    ArgumentError ->
      Logger.debug("SIGWINCH not supported on this platform; resize events disabled")
      :ok
  end
end

defmodule Tui.Terminal.SignalForwarder do
  @behaviour :gen_event

  @impl true
  def init(terminal), do: {:ok, terminal}

  @impl true
  def handle_event(signal, terminal) when signal in [:sigint, :sigterm, :sigwinch] do
    send(terminal, {:signal, signal})
    {:ok, terminal}
  end

  def handle_event(_other, terminal), do: {:ok, terminal}

  @impl true
  def handle_call(_request, terminal), do: {:ok, :ok, terminal}

  @impl true
  def handle_info(_msg, terminal), do: {:ok, terminal}

  @impl true
  def terminate(_reason, _terminal), do: :ok
end
