defmodule Pleroma.Web.ActivityPub.QuoteAuthorizationController do
  use Pleroma.Web, :controller

  alias Pleroma.QuoteAuthorization
  alias Pleroma.User

  action_fallback(:errors)

  def show(conn, %{"nickname" => nickname, "id" => id}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname),
         ap_id <- "#{user.ap_id}/quote_authorizations/#{id}",
         %QuoteAuthorization{data: data} <- QuoteAuthorization.get_by_ap_id(ap_id) do
      conn
      |> put_resp_content_type("application/activity+json")
      |> json(data)
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{"error" => "Not found"})
    end
  end

  defp errors(conn, _) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{"error" => "Something went wrong"})
  end
end
