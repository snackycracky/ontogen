defmodule Ontogen.HistoryType.FormatterTest do
  use OntogenCase

  doctest Ontogen.HistoryType.Formatter

  alias Ontogen.HistoryType.Formatter
  alias RDF.Graph

  describe "default format" do
    test "full dataset history" do
      {commits, history_graph} = commit_history()

      assert {:ok, formatted} =
               formatted_history(history_graph, commits, format: :default, color: false)

      assert formatted <> "\n" =~
               ~r"""
               2235310670 - Test commit \(\d+ .+\) <John Doe john\.doe@example\.com>
               23d9efcfeb - Second commit \(\d+ .+\) <Jane Doe jane\.doe@example\.com>
               c6fa7aecf6 - Initial commit \(\d+ .+\) <John Doe john\.doe@example\.com>
               """
    end
  end

  describe "oneline format" do
    test "full dataset history" do
      {[third, second, first] = commits, history_graph} = commit_history()

      assert {:ok, formatted} =
               formatted_history(history_graph, commits, format: :oneline, color: false)

      assert formatted ==
               """
               #{hash_from_iri(third.__id__)} #{first_line(third.message)}
               #{hash_from_iri(second.__id__)} #{first_line(second.message)}
               #{hash_from_iri(first.__id__)} #{first_line(first.message)}
               """
               |> String.trim_trailing()

      assert {:ok, formatted} =
               formatted_history(history_graph, commits,
                 format: :oneline,
                 changes: :short_stat,
                 color: false
               )

      assert formatted ==
               """
               #{hash_from_iri(third.__id__)} #{first_line(third.message)}
                3 resources changed, 3 insertions(+)

               #{hash_from_iri(second.__id__)} #{first_line(second.message)}
                2 resources changed, 1 insertions(+), 1 deletions(-)

               #{hash_from_iri(first.__id__)} #{first_line(first.message)}
                1 resources changed, 1 insertions(+)
               """
               |> String.trim_trailing()
    end
  end

  describe "short format" do
    test "full dataset history" do
      {[third, second, first] = commits, history_graph} = commit_history()

      assert {:ok, formatted} =
               formatted_history(history_graph, commits, format: :short, color: false)

      assert formatted ==
               """
               commit #{hash_from_iri(third.__id__)}
               Author: John Doe <john.doe@example.com>

               #{third.message}

               commit #{hash_from_iri(second.__id__)}
               Author: John Doe <john.doe@example.com>

               #{second.message}

               commit #{hash_from_iri(first.__id__)}
               Author: John Doe <john.doe@example.com>

               #{first.message}
               """
               |> String.trim_trailing()
    end
  end

  describe "medium format" do
    test "full dataset history" do
      {[third, second, first] = commits, history_graph} = commit_history()

      assert {:ok, formatted} =
               formatted_history(history_graph, commits, format: :medium, color: false)

      assert formatted ==
               """
               commit #{hash_from_iri(third.__id__)}
               Source: <http://example.com/test/dataset>
               Author: John Doe <john.doe@example.com>
               Date:   Fri May 26 13:02:02 2023 +0000

               #{third.message}

               commit #{hash_from_iri(second.__id__)}
               Source: <http://example.com/test/dataset>
               Author: John Doe <john.doe@example.com>
               Date:   Fri May 26 13:02:02 2023 +0000

               #{second.message}

               commit #{hash_from_iri(first.__id__)}
               Source: <http://example.com/test/dataset>
               Author: John Doe <john.doe@example.com>
               Date:   Fri May 26 13:02:02 2023 +0000

               #{first.message}
               """
               |> String.trim_trailing()
    end
  end

  describe "full format" do
    test "full dataset history" do
      {[third, second, first] = commits, history_graph} = commit_history()

      assert {:ok, formatted} =
               formatted_history(history_graph, commits,
                 format: :full,
                 changes: :resource_only,
                 color: false
               )

      assert formatted ==
               """
               commit #{hash_from_iri(third.__id__)}
               Source:     <http://example.com/test/dataset>
               Author:     John Doe <john.doe@example.com>
               AuthorDate: Fri May 26 13:02:02 2023 +0000
               Commit:     John Doe <john.doe@example.com>
               CommitDate: Fri May 26 13:02:02 2023 +0000

               #{third.message}

               http://example.com/s2
               http://example.com/s3
               http://example.com/s4

               commit #{hash_from_iri(second.__id__)}
               Source:     <http://example.com/test/dataset>
               Author:     John Doe <john.doe@example.com>
               AuthorDate: Fri May 26 13:02:02 2023 +0000
               Commit:     Jane Doe <jane.doe@example.com>
               CommitDate: Fri May 26 13:02:02 2023 +0000

               #{second.message}

               http://example.com/s1
               http://example.com/s2

               commit #{hash_from_iri(first.__id__)}
               Source:     <http://example.com/test/dataset>
               Author:     John Doe <john.doe@example.com>
               AuthorDate: Fri May 26 13:02:02 2023 +0000
               Commit:     John Doe <john.doe@example.com>
               CommitDate: Fri May 26 13:02:02 2023 +0000

               #{first.message}

               http://example.com/s1
               """
               |> String.trim_trailing()
    end
  end

  defp formatted_history(history_graph, commits, subject_tuple \\ {:dataset, nil}, opts) do
    {subject_type, subject} = subject_tuple

    commit_id_chain = Enum.map(commits, & &1.__id__)

    opts = Keyword.put_new(opts, :order, {:desc, :parent, commit_id_chain})
    Formatter.history(history_graph, subject_type, subject, opts)
  end

  defp commit_history() do
    commits =
      commits([
        [
          add: graph(1),
          message: "Initial commit"
        ],
        [
          add: graph(2),
          remove: graph(1),
          committer: agent(:agent_jane),
          message: "Second commit"
        ],
        [
          update: graph([2, 3, 4])
        ]
      ])

    history_graph = Enum.reduce(commits, RDF.graph(), &Graph.add(&2, Grax.to_rdf!(&1)))

    {commits, history_graph}
  end
end
