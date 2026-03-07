defmodule ElixirApiCore.AuditTest do
  use ElixirApiCore.DataCase, async: true

  alias ElixirApiCore.Audit
  alias ElixirApiCore.Audit.Event
  alias ElixirApiCore.Auth

  describe "log/1" do
    test "inserts an audit event with required action" do
      assert {:ok, event} = Audit.log(%{action: "test.action"})
      assert event.action == "test.action"
      assert event.id
    end

    test "inserts an audit event with all fields" do
      user_id = Ecto.UUID.generate()
      account_id = Ecto.UUID.generate()

      assert {:ok, event} =
               Audit.log(%{
                 action: "test.full",
                 actor_id: user_id,
                 account_id: account_id,
                 resource_type: "widget",
                 resource_id: Ecto.UUID.generate(),
                 metadata: %{"key" => "value"}
               })

      assert event.actor_id == user_id
      assert event.account_id == account_id
      assert event.resource_type == "widget"
      assert event.metadata == %{"key" => "value"}
    end

    test "returns error when action is missing" do
      assert {:error, changeset} = Audit.log(%{})
      assert %{action: [_ | _]} = errors_on(changeset)
    end
  end

  describe "auth flow audit events" do
    test "register emits user.registered event" do
      assert {:ok, result} =
               Auth.register(%{email: "audit-reg@example.com", password: "password123!"})

      events = Repo.all(from e in Event, where: e.action == "user.registered")
      assert [event] = events
      assert event.actor_id == result.user.id
      assert event.account_id == result.account.id
      assert event.resource_type == "user"
    end

    test "login emits user.logged_in event" do
      {:ok, reg} = Auth.register(%{email: "audit-login@example.com", password: "password123!"})

      assert {:ok, _} = Auth.login(%{email: "audit-login@example.com", password: "password123!"})

      events = Repo.all(from e in Event, where: e.action == "user.logged_in")
      assert [event] = events
      assert event.actor_id == reg.user.id
    end

    test "refresh emits token.refreshed event" do
      {:ok, reg} = Auth.register(%{email: "audit-refresh@example.com", password: "password123!"})

      assert {:ok, _} = Auth.refresh(%{refresh_token: reg.refresh_token})

      events = Repo.all(from e in Event, where: e.action == "token.refreshed")
      assert [event] = events
      assert event.actor_id == reg.user.id
    end

    test "logout emits user.logged_out event" do
      {:ok, reg} = Auth.register(%{email: "audit-logout@example.com", password: "password123!"})

      assert {:ok, _} = Auth.logout(%{refresh_token: reg.refresh_token})

      events = Repo.all(from e in Event, where: e.action == "user.logged_out")
      assert [event] = events
      assert event.actor_id == reg.user.id
      assert event.resource_type == "refresh_token"
    end

    test "switch_account emits account.switched event" do
      {:ok, reg} = Auth.register(%{email: "audit-switch@example.com", password: "password123!"})
      other = account_fixture()

      {:ok, _} =
        ElixirApiCore.Accounts.create_membership(%{
          user_id: reg.user.id,
          account_id: other.id,
          role: :member
        })

      assert {:ok, _} = Auth.switch_account(reg.user.id, other.id)

      events = Repo.all(from e in Event, where: e.action == "account.switched")
      assert [event] = events
      assert event.actor_id == reg.user.id
      assert event.account_id == other.id
    end

    test "failed operations do not emit audit events" do
      Auth.login(%{email: "nobody@example.com", password: "wrong"})
      Auth.logout(%{refresh_token: "garbage"})

      assert [] = Repo.all(Event)
    end
  end
end
