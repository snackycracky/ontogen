defmodule Ontogen.CommitIdChainTest do
  use Ontogen.RepositoryCase, async: false

  doctest Ontogen.CommitIdChain

  alias Ontogen.{CommitIdChain, Commit, InvalidCommitRangeError}

  describe "fetch/3" do
    test "on a clean repo without commits", %{repo: repo, store: store} do
      assert CommitIdChain.fetch(:head, store, repo) == {:error, :no_head}
    end

    test "with commit in history", %{store: store} do
      [fourth, third, second, first] = history = init_history()

      assert CommitIdChain.fetch(:head, store, Ontogen.repository()) == {:ok, history}
      assert CommitIdChain.fetch(fourth, store, Ontogen.repository()) == {:ok, history}

      assert CommitIdChain.fetch(third, store, Ontogen.repository()) ==
               {:ok, Enum.slice(history, 1..3)}

      assert CommitIdChain.fetch(second, store, Ontogen.repository()) ==
               {:ok, Enum.slice(history, 2..3)}

      assert CommitIdChain.fetch(first, store, Ontogen.repository()) ==
               {:ok, Enum.slice(history, 3..3)}
    end

    test "with independent commit", %{store: store} do
      init_history()
      independent_commit = commit()

      assert CommitIdChain.fetch(independent_commit, store, Ontogen.repository()) ==
               {:error, %InvalidCommitRangeError{reason: :out_of_range}}
    end

    test "with commit range in history", %{store: store} do
      [fourth, third, second, first] = history = init_history()

      assert Commit.Range.new!(base: first) |> CommitIdChain.fetch(store, Ontogen.repository()) ==
               {:ok, Enum.slice(history, 0..2)}

      assert Commit.Range.new!(base: third) |> CommitIdChain.fetch(store, Ontogen.repository()) ==
               {:ok, Enum.slice(history, 0..0)}

      assert Commit.Range.new!(base: fourth) |> CommitIdChain.fetch(store, Ontogen.repository()) ==
               {:ok, []}

      assert Commit.Range.new!(target: fourth)
             |> CommitIdChain.fetch(store, Ontogen.repository()) == {:ok, history}

      assert Commit.Range.new!(target: first) |> CommitIdChain.fetch(store, Ontogen.repository()) ==
               {:ok, Enum.slice(history, 3..3)}

      assert Commit.Range.new!(base: first, target: fourth)
             |> CommitIdChain.fetch(store, Ontogen.repository()) ==
               {:ok, Enum.slice(history, 0..2)}

      assert Commit.Range.new!(base: second, target: third)
             |> CommitIdChain.fetch(store, Ontogen.repository()) ==
               {:ok, Enum.slice(history, 1..1)}

      assert Commit.Range.new!(range: {second, third})
             |> CommitIdChain.fetch(store, Ontogen.repository()) ==
               {:ok, Enum.slice(history, 1..1)}
    end

    test "with independent commits in commit range", %{store: store} do
      [fourth, _third, _second, first] = init_history()
      independent_commit = commit()

      assert Commit.Range.new!(range: {first, independent_commit})
             |> CommitIdChain.fetch(store, Ontogen.repository()) ==
               {:error, %InvalidCommitRangeError{reason: :out_of_range}}

      assert Commit.Range.new!(range: {independent_commit, fourth})
             |> CommitIdChain.fetch(store, Ontogen.repository()) ==
               {:error, %InvalidCommitRangeError{reason: :out_of_range}}
    end

    test "when the specified target commit comes later than the base commit", %{store: store} do
      [fourth, _third, _second, first] = init_history()

      assert Commit.Range.new!(base: fourth, target: first)
             |> CommitIdChain.fetch(store, Ontogen.repository()) ==
               {:error, %InvalidCommitRangeError{reason: :out_of_range}}
    end
  end

  defp init_history do
    graph = [
      EX.S1 |> EX.p1(EX.O1),
      EX.S2 |> EX.p2(42, "Foo")
    ]

    init_commit_history([
      [
        add: graph,
        message: "Initial commit"
      ],
      [
        # this leads to a different effective change
        add: [{EX.S3, EX.p3(), "foo"}],
        remove: EX.S1 |> EX.p1(EX.O1),
        committer: agent(:agent_jane),
        message: "Second commit"
      ],
      [
        # this leads to a different effective change
        add: [{EX.S4, EX.p4(), EX.O4}, {EX.S3, EX.p3(), "foo"}],
        message: "Third commit",
        committer: id(:agent_john)
      ],
      [
        # this leads to a different effective change
        update: [{EX.S5, EX.p5(), EX.O5}, graph],
        message: "Fourth commit"
      ]
    ])
    |> Enum.map(& &1.__id__)
  end
end
