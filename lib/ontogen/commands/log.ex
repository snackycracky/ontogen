defmodule Ontogen.Commands.Log do
  alias Ontogen.{Store, Repository, LogType}
  alias Ontogen.Commands.Log.Query

  import RDF.Guards

  def dataset(store, repository, opts \\ []) do
    call(store, repository, {:dataset, Repository.dataset_graph_id(repository)}, opts)
  end

  def resource(store, repository, resource, opts \\ []) do
    call(store, repository, {:resource, normalize_resource(resource)}, opts)
  end

  def call(store, repository, subject, opts \\ []) do
    with {:ok, query} <- Query.build(repository, subject, opts),
         {:ok, history_graph} <-
           Store.construct(store, Repository.prov_graph_id(repository), query, raw_mode: true) do
      LogType.log(history_graph, subject, opts)
    end
  end

  defp normalize_resource(resource) when is_rdf_resource(resource), do: resource
  defp normalize_resource(resource), do: RDF.iri(resource)
end
