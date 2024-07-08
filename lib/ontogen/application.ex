defmodule Ontogen.Application do
  @moduledoc false

  use Application

  @env Mix.env()

  @impl true
  def start(_type, _args) do
    Ontogen.Bog.create_salt_base_path()

    children = children(@env)

    opts = [strategy: :one_for_one, name: Ontogen.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp children(:test), do: []
  defp children(_), do: [Ontogen]
end
