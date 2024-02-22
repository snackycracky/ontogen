defmodule Ontogen.CommitTest do
  use OntogenCase

  doctest Ontogen.Commit

  alias Ontogen.{Commit, Proposition, InvalidChangesetError}

  describe "new/1" do
    test "with all required attributes" do
      message = "Initial commit"

      assert {:ok, %Commit{} = commit} =
               Commit.new(
                 speech_act: speech_act(),
                 add: proposition(),
                 committer: agent(),
                 message: message,
                 time: datetime()
               )

      assert %IRI{value: "urn:hash::sha256:" <> _} = commit.__id__

      assert commit.add == proposition()
      assert commit.speech_act == speech_act()
      assert commit.committer == agent()
      assert commit.message == message
      assert commit.time == datetime()
      refute commit.parent
      assert Commit.root?(commit)
    end

    test "implicit proposition creation" do
      assert {:ok, %Commit{} = commit} =
               Commit.new(
                 speech_act: speech_act(),
                 add: EX.S1 |> EX.p1(EX.O1),
                 remove: {EX.S2, EX.P2, EX.O2},
                 committer: agent(),
                 message: "Some commit",
                 time: datetime()
               )

      assert commit.add == proposition(EX.S1 |> EX.p1(EX.O1))
      assert commit.remove == proposition({EX.S2, EX.P2, EX.O2})
      assert commit.speech_act == speech_act()
    end

    test "with changeset" do
      assert {:ok, %Commit{} = commit} =
               Commit.new(
                 speech_act: speech_act(),
                 changeset: commit_changeset(),
                 committer: agent(),
                 message: "Some commit",
                 time: datetime()
               )

      assert commit.add == commit_changeset().add |> Proposition.new!()
      assert commit.remove == commit_changeset().remove |> Proposition.new!()
      assert commit.update == commit_changeset().update
      assert commit.replace == commit_changeset().replace
      assert commit.speech_act == speech_act()
    end

    test "shared add and remove statement" do
      shared_statements = [{EX.s(), EX.p(), EX.o()}]

      assert Commit.new(
               add: graph() |> Graph.add(shared_statements),
               remove: shared_statements,
               committer: agent(),
               message: "Inserted and removed statement",
               time: datetime()
             ) ==
               {:error,
                InvalidChangesetError.exception(
                  reason:
                    "the following statements are in both add and remove: #{inspect(shared_statements)}"
                )}
    end

    test "without statements" do
      assert Commit.new(
               committer: agent(),
               message: "without added and removed statements",
               time: datetime()
             ) ==
               {:error, InvalidChangesetError.exception(reason: :empty)}
    end
  end
end
