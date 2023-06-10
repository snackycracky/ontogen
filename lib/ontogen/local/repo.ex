defmodule Ontogen.Local.Repo do
  @moduledoc """
  A local Ontogen repo of a dataset and its provenance history.
  """

  use GenServer

  alias Ontogen.Local.Repo.{Initializer, NotReadyError}
  alias Ontogen.Commands.{RepoInfo, Commit, FetchHistory, FetchDataset, FetchProvGraph}

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  def store do
    GenServer.call(__MODULE__, :store)
  end

  def repository do
    GenServer.call(__MODULE__, :repository)
  end

  def dataset_info do
    GenServer.call(__MODULE__, :dataset_info)
  end

  def prov_graph_info do
    GenServer.call(__MODULE__, :prov_graph_info)
  end

  def fetch_dataset do
    # We're not performing the store access inside of the GenServer,
    # because we don't wont to block it for this potentially large read access.
    # Also, we don't to pass the potentially large data structure between processes.
    FetchDataset.call(store(), repository())
  end

  def fetch_prov_graph do
    # We're not performing the store access inside of the GenServer,
    # because we don't wont to block it for this potentially large read access.
    # Also, we don't to pass the potentially large data structure between processes.
    FetchProvGraph.call(store(), repository())
  end

  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  def create(repo_spec, opts \\ []) do
    GenServer.call(__MODULE__, {:create, repo_spec, opts})
  end

  def commit(args) do
    GenServer.call(__MODULE__, {:commit, args})
  end

  def dataset_history(args \\ []) do
    GenServer.call(__MODULE__, {:dataset_history, args})
  end

  def resource_history(resource, args \\ []) do
    GenServer.call(__MODULE__, {:resource_history, resource, args})
  end

  def head do
    GenServer.call(__MODULE__, :head)
  end

  # Server (callbacks)

  @impl true
  def init(opts) do
    store = Initializer.store(opts)

    case Initializer.repository(opts) do
      {:ok, repository} ->
        IO.puts("Connected to repo #{repository.__id__}")
        {:ok, %{repository: repository, store: store, status: :ready}}

      {:error, :repo_not_defined} ->
        IO.puts("Repo not specified, you'll have to create one first.")
        {:ok, %{repository: nil, store: store, status: :no_repo}}

      {:error, :repo_not_found} ->
        IO.puts("Repo not found, you'll have to create one first.")
        {:ok, %{repository: nil, store: store, status: :no_repo}}

      {:error, error} ->
        {:stop, error}
    end
  end

  @impl true
  def handle_call(:status, _from, %{status: status} = state) do
    {:reply, status, state}
  end

  def handle_call(:store, _from, %{store: store} = state) do
    {:reply, store, state}
  end

  def handle_call({:create, repo_spec, opts}, _from, %{store: store, status: :no_repo} = state) do
    case Initializer.create_repo(store, repo_spec, opts) do
      {:ok, repo} -> {:reply, {:ok, repo}, %{state | repository: repo, status: :ready}}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:create, _, _}, _from, state) do
    {:reply, {:error, :repo_already_connected}, state}
  end

  def handle_call(operation, _from, %{status: :no_repo} = state) do
    {:reply, {:error, NotReadyError.exception(operation: operation)}, state}
  end

  def handle_call(:reload, _from, %{store: store, repository: repository} = state) do
    case RepoInfo.call(store, repository.__id__) do
      {:ok, repo} -> {:reply, {:ok, repo}, %{state | repository: repo}}
      error -> {:reply, error, state}
    end
  end

  def handle_call(:repository, _from, %{repository: repo} = state) do
    {:reply, repo, state}
  end

  def handle_call(:dataset_info, _from, %{repository: repo} = state) do
    {:reply, repo && repo.dataset, state}
  end

  def handle_call(:prov_graph_info, _from, %{repository: repo} = state) do
    {:reply, repo && repo.prov_graph, state}
  end

  def handle_call(:head, _from, %{repository: repo} = state) do
    {:reply, repo && repo.dataset.head, state}
  end

  def handle_call({:commit, args}, _from, %{repository: repo, store: store} = state) do
    case Commit.call(store, repo, args) do
      {:ok, repo, commit, utterance} ->
        {:reply, {:ok, commit, utterance}, %{state | repository: repo}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:dataset_history, args}, _from, %{repository: repo, store: store} = state) do
    case FetchHistory.dataset(store, repo, args) do
      {:ok, history} -> {:reply, {:ok, history}, state}
      error -> {:reply, error, state}
    end
  end

  def handle_call(
        {:resource_history, resource, args},
        _from,
        %{repository: repo, store: store} = state
      ) do
    case FetchHistory.resource(store, repo, resource, args) do
      {:ok, history} -> {:reply, {:ok, history}, state}
      error -> {:reply, error, state}
    end
  end
end
