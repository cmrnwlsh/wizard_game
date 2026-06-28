# TODO build this next

defmodule Tui.Log do
  use GenServer
end

defmodule Tui.Log.Entry do
  alias __MODULE__
  defstruct [:id, :time, :level, :message, :meta]

  def new(%{level: level, msg: msg, meta: meta}) do
    %Entry{}
  end
end

defmodule Tui.Log.Handler do
  @behaviour :logger_handler
end
